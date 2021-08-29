### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 48463954-2d4b-46fa-81ad-3e3c52420702
begin
	import Pkg
	Pkg.activate(pwd())
	Pkg.add([
			"PlutoUI", "HTTP", "CSV", "DataFrames", 
			"Impute", "Plots", "StatsPlots"
			])
	
	using Dates, PlutoUI, DataFrames, Impute, Plots, StatsPlots
	import LinearAlgebra, HTTP, CSV
	
	gr()
	Plots.GRBackend()
	Plots.default(
		legend = :topleft,
		minorgrid = true,
		color_palette = :seaborn_deep,
		size = (700, 400),
		formatter = :plain
	)
	
	PALETTE_COLORS = palette(:seaborn_deep)
end;

# ╔═╡ 52c5aa3b-31c9-41d6-b840-b766d8724932
md"## Plots"

# ╔═╡ ec4728d1-2bc4-4da7-8290-565aaaf092b2
md"**$(@bind check_use_log_scale CheckBox()) Use logarithmic scale**"

# ╔═╡ fc216607-af60-431a-bac5-53240596b6a9
md"### By location"

# ╔═╡ 873db3d5-af35-4d03-b4ff-5a1f10ab4924
md"#### Select locations for comparison"

# ╔═╡ 70584069-db75-4f6b-aa0d-43de20a36ed8
md"## References"

# ╔═╡ 87d376c4-074c-11ec-3a91-27b12d84faef
SEEDS = Dict(
	:vnexpress => [
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_total",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_location",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_day",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_by_map",
		"https://vnexpress.net/microservice/sheet/type/covid19_2021_281",
		# This one is JSON and it's not important parsing this
		# "https://vnexpress.net/microservice/sheet/type/vaccine_covid_19",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_vietnam_city",
		"https://vnexpress.net/microservice/sheet/type/vaccine_to_vietnam",
		"https://vnexpress.net/microservice/sheet/type/vaccine_data_map",
	]
)

# ╔═╡ 4df3b761-c69a-4b96-81dc-08177d044447
md"## Glossary"

# ╔═╡ 2f303728-e590-4b45-8e89-53b48f9ef242
md"### Data retrievals"

# ╔═╡ 88e4d0b5-7024-45e4-b867-6da55f726d17
DATAFRAMES_RAW = Dict(asyncmap(collect(keys(SEEDS))) do srcname
	srcname => Dict(asyncmap(SEEDS[srcname]) do url
		r = HTTP.get(url)
		df = CSV.read(r.body, DataFrame)
		dfname = Symbol(last(split(url, c -> c == '/')))
		dfname => df
		end)
	end);

# ╔═╡ 06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
LOCATIONS = sort!(names(DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_location])[2:63])

# ╔═╡ fd11d312-8082-4faf-9551-dc597687f4ef
@bind locs_to_plot_binding MultiCheckBox(LOCATIONS)

# ╔═╡ b1cd1aa6-2dfe-4d02-983a-aa440d44550f
begin
	locs_to_plot = []
	if !isnothing(locs_to_plot_binding)
		append!(locs_to_plot, [Symbol(loc) for loc in locs_to_plot_binding])
	end
end;

# ╔═╡ d9dabd88-5e88-4b94-816e-3545f598100b
DATES = Date(2021, 4, 27):Dates.Day(1):Dates.today()

# ╔═╡ bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
md"### Cleaned dataframes"

# ╔═╡ f8b80935-e3fc-4224-82a9-adf88c3bcc97
DATAFRAMES = Dict(
	:vnexpress => Dict{Symbol, DataFrame}(),
);

# ╔═╡ 9f7c09d8-fc02-4894-9cb3-c17ea157c71b
let df = transform(DATAFRAMES[:vnexpress][:covid19_2021_by_day],
		# Calculate mortality
		[:deaths_cummulative, :cases_cummulative]
			=> ((deaths, cases) -> deaths.//cases.*100)
			=> :mortality,
	)
	
	# Avoid having 0 values in dataframe when plot with logarithmic scale
	if check_use_log_scale
		df[!, [:cases_investigating,
				:cases_quarantined,
				:cases_imported]] .+= 1
	end

	let # Plot daily new cases
		subplot_daily = @df df myareaplot(
			:date,
			[:cases_investigating :cases_quarantined :cases_imported];
			label = ["new cases from unknown source" "new cases under quarantine" "new cases from immigrants"],
			yscale = check_use_log_scale ? :log10 : :identity,
		);

		subplot_mortality = @df df plot(
			:date, :mortality,
			color = PALETTE_COLORS[4],
			label = "mortality rate (%)",
			rotation = 45,
		)

		# Plot cummulative cases
		subplot_cummulative = @df df plot(
			:date, :cases_cummulative;
			label = "cummulative cases",
			color = PALETTE_COLORS[5],
			linetype = :bar,
			linecolor = :match,
			rotation = 45,
			yscale = check_use_log_scale ? :log10 : :identity,
		)

		plot(subplot_daily, subplot_mortality, subplot_cummulative,
			plot_title = "Overview (since $(DATES[1]))",
			layout = @layout([a{0.6h}; b c]),
			size = (700, 700)
		)
	end
end

# ╔═╡ bc1d8e14-0be1-4b87-a129-7b39251d60c5
let df = transform(DATAFRAMES[:vnexpress][:covid19_2021_by_day],
		# Normalized cummulative active cases over cummulative cases
		[:cases_cummulative, :deaths_cummulative, :recovered_cummulative]
			=> ((x, y, z) -> 1 .- y.//x .- z.//x)
			=> :cases_cummulative_active_weight,
		# Normalized cummulative deaths over cummulative cases
		[:cases_cummulative, :deaths_cummulative]
			=> ((x, y) -> y .// x)
			=> :deaths_cummulative_weight,
		# Normalized cummulative recovered cases over cummulative cases
		[:cases_cummulative, :recovered_cummulative]
			=> ((x, y) -> y .// x)
			=> :recovered_cummulative_weight,
		# Calculate percentage of cases that are on ICU
		[:cases_cummulative_on_icu, :cases_cummulative]
			=> ((x, y) -> x .// y .* 100)
			=> :cases_cummulative_on_icu_percent,
		# Calculate percentage of cases that are on ECMO
		[:cases_cummulative_on_ecmo, :cases_cummulative]
			=> ((x, y) -> x .// y .* 100)
			=> :cases_cummulative_on_ecmo_percent,
	);
	
	let # Plot area chart for active cases, deaths and recovered
		subplot_composition = @df df areaplot(
				:date,
				cols([:cases_cummulative_active_weight,
					:recovered_cummulative_weight,
					:deaths_cummulative_weight]);
				label = ["active cases (%)" "recovered (%)" "deaths (%)"],
				palette = PALETTE_COLORS[2:end],
				legend = :outertop,
				rotation = 45,
			);
		subplot_lifesupport = @df df areaplot(:date,
			cols([:cases_cummulative_on_icu_percent,
					:cases_cummulative_on_ecmo_percent
				]),
			label = ["on ICU (%)" "on ECMO (%)"],
			palette = PALETTE_COLORS[8:end],
			rotation = 45,
			);
		
		plot(
			subplot_composition, subplot_lifesupport,
			plot_title = "Compositions (since $(DATES[1]))",
			layout = @layout([a b])
		)
	end
end

# ╔═╡ a606da0f-2f60-4b12-a56a-8ef9261c8cc6
let considered_date = Dates.today();
	# Copy the original dataframe
	df = filter(x -> x.date <= considered_date,
		DATAFRAMES[:vnexpress][:covid19_2021_by_location]);
	# Sort and get the top 8 locations with highest cummulative cases
	top8 = sort(filter(
			cols -> cols.date == considered_date,
			stack(df, (2:size(df, 2)))
			), 
		order(:value, rev=true)
	)[1:8, :variable]
	
	if sum(last(df)[2:end]) != 0
		# Filter out locations that are not in the top 8
		select!(df, :date, top8)

		# Avoid having 0 values in dataframe when plot with logarithmic scale
		if check_use_log_scale
			df[!, top8] .+= 1
		end

		@df df plot(
			:date, cols([Symbol(loc) for loc in top8]),
			plot_title = "Daily new cases (since $(DATES[1]))",
			label_title = "Top 8 of $considered_date",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = check_use_log_scale ? :log10 : :identity,
		)
	else
		md"**Daily cases on $considered_date is not available for ranking**"
	end
end

# ╔═╡ 908d8a8a-eaa5-4648-ae3d-d2bcba501379
let # Copy the original dataframe
	df = copy(DATAFRAMES[:vnexpress][:covid19_2021_by_total]);
	# Sort and get the top 8 locations with highest cummulative cases
	top8 = sort(filter(
			cols -> cols.date == Dates.today(),
			stack(df, (2:size(df, 2)))
			), 
		order(:value, rev=true)
	)[1:8, :variable]
	
	# Filter out locations that are not in the top 8
	select!(df, :date, top8);		
	
	# Avoid having 0 values in dataframe when plot with logarithmic scale
	if check_use_log_scale
		df[!, top8] .+= 1
	end

	@df df plot(
		:date, cols([Symbol(loc) for loc in top8]),
		plot_title = "Cummulative cases (since $(DATES[1]))",
		label_title = "Top 8",
		xlabel = "Date",
		ylabel = "Cases count",
		yscale = check_use_log_scale ? :log10 : :identity,
	)
end

# ╔═╡ c7df24e3-37ff-45ea-950d-99f3c1c711ce
if !isempty(locs_to_plot)
	let df = copy(DATAFRAMES[:vnexpress][:covid19_2021_by_total])
		# Avoid -Inf with log
		if check_use_log_scale
			df[!, locs_to_plot] .+= 1
		end

		@df df plot(
			:date, cols(locs_to_plot);
			plot_title = "Cummulative cases (since $(DATES[1]))",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = check_use_log_scale ? :log10 : :identity,
		)
	end
end

# ╔═╡ eef505a5-0a58-4137-99e6-7effb2daf830
if !isempty(locs_to_plot)
	let df = copy(DATAFRAMES[:vnexpress][:covid19_2021_by_location])
		# Avoid -Inf with log
		if check_use_log_scale
			df[!, locs_to_plot] .+= 1
		end

		@df df plot(
			:date, cols(locs_to_plot);
			plot_title = "Daily cases (since $(DATES[1]))",
			xlabel = "Date",
			ylabel = "Cases count",
			yscale = check_use_log_scale ? :log10 : :identity,
		)
	end
end

# ╔═╡ 5da0ef7d-ab07-403b-b9b3-7928202eebdb
md"#### Daily summaries"

# ╔═╡ f7549e5f-60f1-4530-bec4-88b020f65a46
md"#### Cummulative cases since 27th April"

# ╔═╡ 8e812230-5284-4a9a-b16a-c054a12407f5
md"#### Daily cases since 27th April"

# ╔═╡ ab548612-82a5-48fa-b81c-aae646666997
md"### Packages"

# ╔═╡ 85665111-9c21-457d-b4c2-d12521761522
md"### Helper functions"

# ╔═╡ 4b600132-f50e-4aaf-9646-a2bc4d643634
hasmissing(df::DataFrame) =
	any(Iterators.flatten(map(row -> ismissing.(values(row)), eachrow(df))))

# ╔═╡ dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
let df = copy(DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_day])
	# Rename columns and parse date column
	select!(
		df,
		"day_full" => (x -> Date.(x, dateformat"Y/m/d")) => :date,
		# All daily cases
		"new_cases" => :cases,
		# Daily active cases
		"new_active" => :cases_active,
		# Daily cases within the community
		"CỘNG ĐỒNG" => :cases_community,
		"blockade" => :cases_quarantined,
		"community" => :cases_investigating,
		# Daily cases from immigrants
		"imported" => :cases_imported,
		# All cummulative cases (since 27/04)
		"total_cases" => :cases_cummulative,
		# Cummulative active cases
		"total_active" => :cases_cummulative_active,
		# Cummulative cases within the community
		"TỔNG CỘNG ĐỒNG" => :cases_cummulative_community,
		# Cummulative cases with severe conditions 
		"ECMO" => :cases_cummulative_on_ecmo,
		"ICU_52" => :cases_cummulative_on_icu,
		# Daily deaths
		"new_deaths" => :deaths,
		# Cummulative deaths
		"total_deaths" => :deaths_cummulative,
		# Daily recovered
		"new_recovered" => :recovered,
		# Cummulative recovered
		"total_recovered_12" => :recovered_cummulative,
	)
	
	# Collect data within valid dates
	filter!(cols -> cols.date in DATES, df)
	
	# Replace missing cases under investigation with total number of cases
	# in the community. This is done because in earlier dates, there's no
	# report on this particular number.
	df[!, "cases_investigating"] = 
		coalesce.(df[!, :cases_investigating], df[!, :cases_community])
	
	# Replace missing cases in quarantine with 0, because we already assume
	# all community cases are not quarantined in dates with missing data
	df[!, "cases_quarantined"] = 
	 	coalesce.(df[!, :cases_quarantined], 0)
	
	# Use Last Observered Carried Forward replacement strategy for cases
	# on ECMO and ICU, while setting the initial number to 0.
	cols_cumulative_locf = [:cases_cummulative_on_ecmo, :cases_cummulative_on_icu]
	df[1, cols_cumulative_locf[1]] = 0
	df[1, cols_cumulative_locf[2]] = 0
	df[!, cols_cumulative_locf] = Impute.locf(df[!, cols_cumulative_locf])
	
	@assert !hasmissing(df)
	DATAFRAMES[:vnexpress][:covid19_2021_by_day] = df
end

# ╔═╡ 0b642ad0-8648-41bd-8d75-062a50a0e0e3
let df = copy(DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_total])
	# Remove the first row that has missing date
	delete!(df, 1)
	
	# Convert string to date and only select needed columns
	select!(df,
		"Ngày" => (x -> Date.(x .* "/2021", dateformat"d/m/Y")) => :date,
		LOCATIONS
	)
	
	# Should be no missing field
	@assert !hasmissing(df)
	DATAFRAMES[:vnexpress][:covid19_2021_by_total] = df
end

# ╔═╡ ed4ebadd-adb7-4c97-a044-48fcc37064b8
let df = copy(DATAFRAMES_RAW[:vnexpress][:covid19_2021_by_location])
	# Remove the first row that has missing date
	delete!(df, 1)
	
	# Convert string to date and only select needed columns
	select!(df,
		"Ngày" => (x -> Date.(x .* "/2021", dateformat"d/m/Y")) => :date,
		LOCATIONS
	)
	
	# Replace missing with 0
	df = coalesce.(df, 0)
	
	# Should be no missing field
	@assert !hasmissing(df)
	DATAFRAMES[:vnexpress][:covid19_2021_by_location] = df
end

# ╔═╡ 7b9759f1-f696-4d50-822d-88df713fb575
begin
	@userplot MyAreaPlot

	@recipe function f(a::MyAreaPlot)
		data = cumsum(a.args[end], dims = 2)
		x = length(a.args) == 1 ? (axes(data, 1)) : a.args[1]
		seriestype := :line
		for i in axes(data, 2)
			@series begin
				fillrange := i > 1 ? data[:, i - 1] : 1
				x, data[:, i]
			end
		end
	end
end

# ╔═╡ bb6d4ca5-3eb6-4405-90f5-add2d5f1c4ea
let df = copy(DATAFRAMES[:vnexpress][:covid19_2021_by_day])
		
	if check_use_log_scale
		df[!, [:deaths,
				:deaths_cummulative,
				:recovered,
				:recovered_cummulative,
				:cases_cummulative_active]] .+= 1
	end
	
	let	subplot_active_cumsum = @df df plot(
			:date, :cases_cummulative_active,
			label = "active cases",
			rotation = 45,
			linetype = :bar,
			linecolor = :match,
			color = PALETTE_COLORS[2],
			yscale = check_use_log_scale ? :log10 : :identity
			);
		subplot_active_diff = @df df plot(
			:date, :cases_active,
			label = "active cases' diff.",
			rotation = 45,
			linecolor = :match,
			color = PALETTE_COLORS[2]
			);
	
		subplot_recovered_cumsum = @df df plot(
			:date, :recovered_cummulative,
			label = "total recovered",
			rotation = 45,
			linetype = :bar,
			linecolor = :match,
			color = PALETTE_COLORS[3],
			yscale = check_use_log_scale ? :log10 : :identity
			);
		subplot_recovered_daily = @df df plot(
			:date, :recovered,
			label = "daily recovered",
			rotation = 45,
			linecolor = :match,
			color = PALETTE_COLORS[3],
			yscale = check_use_log_scale ? :log10 : :identity
			);

		subplot_deaths_cumsum = @df df plot(
			:date, :deaths_cummulative,
			label = "total deaths",
			rotation = 45,
			linetype = :bar,
			linecolor = :match,
			color = PALETTE_COLORS[4],
			yscale = check_use_log_scale ? :log10 : :identity,
			);
		subplot_deaths_daily = @df df plot(
			:date, :deaths,
			label = "daily deaths",
			rotation = 45,
			linecolor = :match,
			color = PALETTE_COLORS[4],
			yscale = check_use_log_scale ? :log10 : :identity,
			)
		
		plot(
			subplot_active_cumsum, subplot_active_diff,
			subplot_recovered_cumsum, subplot_recovered_daily,
			subplot_deaths_cumsum, subplot_deaths_daily,
			plot_title = "Cases' status (since $(DATES[1]))",
			size = (700, 900),
			layout = @layout([a b; c d; e f])
		)
	end
end

# ╔═╡ Cell order:
# ╟─52c5aa3b-31c9-41d6-b840-b766d8724932
# ╟─ec4728d1-2bc4-4da7-8290-565aaaf092b2
# ╟─9f7c09d8-fc02-4894-9cb3-c17ea157c71b
# ╠═bc1d8e14-0be1-4b87-a129-7b39251d60c5
# ╠═bb6d4ca5-3eb6-4405-90f5-add2d5f1c4ea
# ╟─fc216607-af60-431a-bac5-53240596b6a9
# ╠═a606da0f-2f60-4b12-a56a-8ef9261c8cc6
# ╠═908d8a8a-eaa5-4648-ae3d-d2bcba501379
# ╟─873db3d5-af35-4d03-b4ff-5a1f10ab4924
# ╟─fd11d312-8082-4faf-9551-dc597687f4ef
# ╟─b1cd1aa6-2dfe-4d02-983a-aa440d44550f
# ╟─c7df24e3-37ff-45ea-950d-99f3c1c711ce
# ╟─eef505a5-0a58-4137-99e6-7effb2daf830
# ╟─70584069-db75-4f6b-aa0d-43de20a36ed8
# ╟─87d376c4-074c-11ec-3a91-27b12d84faef
# ╟─4df3b761-c69a-4b96-81dc-08177d044447
# ╟─2f303728-e590-4b45-8e89-53b48f9ef242
# ╠═88e4d0b5-7024-45e4-b867-6da55f726d17
# ╟─06f0d4dc-25a2-4b3f-8558-d0b4935f7e99
# ╟─d9dabd88-5e88-4b94-816e-3545f598100b
# ╟─bcc7b16f-9714-45e9-92bd-70dbea4b4cc6
# ╠═f8b80935-e3fc-4224-82a9-adf88c3bcc97
# ╟─5da0ef7d-ab07-403b-b9b3-7928202eebdb
# ╟─dede2946-ee8b-4a78-b9a6-e7e51eeeb41f
# ╟─f7549e5f-60f1-4530-bec4-88b020f65a46
# ╟─0b642ad0-8648-41bd-8d75-062a50a0e0e3
# ╟─8e812230-5284-4a9a-b16a-c054a12407f5
# ╟─ed4ebadd-adb7-4c97-a044-48fcc37064b8
# ╟─ab548612-82a5-48fa-b81c-aae646666997
# ╠═48463954-2d4b-46fa-81ad-3e3c52420702
# ╟─85665111-9c21-457d-b4c2-d12521761522
# ╠═4b600132-f50e-4aaf-9646-a2bc4d643634
# ╠═7b9759f1-f696-4d50-822d-88df713fb575
