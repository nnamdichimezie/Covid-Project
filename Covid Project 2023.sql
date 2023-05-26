SELECT *
FROM CovidDeaths
where continent is not null
ORDER BY 3,4


--select *
--from CovidVaccinations
--order by 3,4

-- Select Data that we are going to be starting with
Select Location, date, total_cases, new_cases, total_deaths, population
From CovidDeaths
order by 1,2

-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country

SELECT Location, date, total_cases, total_deaths, (CAST(total_deaths AS float) / CAST(total_cases AS float)) * 100 as DeathPercentage
FROM CovidDeaths
where location like '%states%'
ORDER BY 1,2

-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

SELECT location, date, population, total_cases, (CAST(total_cases AS float) / CAST(population AS float)) * 100 as percent_pop_infected
FROM CovidDeaths
where location like '%states%'
ORDER BY 1,2

-- Countries with Highest Infection Rate compared to Population

SELECT location, population, max(total_cases) as highest_infection_count, Max((CAST(total_cases AS float) / CAST(population AS float)) * 100) as percent_pop_infected
FROM CovidDeaths
group by location, population
ORDER BY percent_pop_infected desc

--Countries with Highest Death Count per Population
SELECT location, max(cast(total_deaths as int)) as TotalDeathCount
FROM CovidDeaths
where continent is not null
group by location
ORDER BY TotalDeathCount desc

-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count per population

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From CovidDeaths
Where continent is not null 
Group by continent
order by TotalDeathCount desc

-- GLOBAL NUMBERS

SELECT date, SUM(new_cases) as total_cases, SUM(CAST(new_deaths AS int)) as total_deaths,
       (SUM(CAST(new_deaths AS float)) / NULLIF(SUM(new_cases), 0)) * 100 as DeathPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1 desc,2

-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine


SELECT cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
       sum(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) as cumulative_vaccinations,
       (CAST(SUM(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) AS float) / CAST(cd.population AS float)) * 100 as vaccination_percentage
FROM CovidDeaths as cd
JOIN CovidVaccinations as cv
ON cd.location = cv.location
AND cd.date = cv.date
WHERE cd.continent IS NOT NULL
ORDER BY cd.location, cd.date;

---USING CTE

WITH CumulativeVaccinationData AS (
  SELECT cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
         sum(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) as cumulative_vaccinations
  FROM CovidDeaths as cd
  JOIN CovidVaccinations as cv
  ON cd.location = cv.location
  AND cd.date = cv.date
  WHERE cd.continent IS NOT NULL
)

SELECT *, (CAST(cumulative_vaccinations AS float) / CAST(population AS float)) * 100 as vaccination_percentage
FROM CumulativeVaccinationData
ORDER BY location, date;


--USING TEMP TABLE
-- Create a temporary table
DROP TABLE if exists #CumulativeVaccinationData
CREATE TABLE #CumulativeVaccinationData (
  Continent NVARCHAR(255),
  Location NVARCHAR(255),
  Date DATE,
  Population BIGINT,
  New_Vaccinations BIGINT,
  Cumulative_Vaccinations BIGINT
);
-- Insert data into the temporary table
INSERT INTO #CumulativeVaccinationData (Continent, Location, Date, Population, New_Vaccinations, Cumulative_Vaccinations)
SELECT cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
       SUM(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) as cumulative_vaccinations
FROM CovidDeaths as cd
JOIN CovidVaccinations as cv
ON cd.location = cv.location
AND cd.date = cv.date
WHERE cd.continent IS NOT NULL;

-- Query the temporary table
SELECT *, (CAST(Cumulative_Vaccinations AS float) / CAST(Population AS float)) * 100 as vaccination_percentage
FROM #CumulativeVaccinationData
ORDER BY Location, Date;


-- Creating View to store data for later visualizations
-- Drop the view if it exists

IF EXISTS (SELECT * FROM sys.views WHERE name = 'CumulativeVaccinationView')
DROP VIEW CumulativeVaccinationView;
GO
-- Create the view to store data for later visualizations
CREATE VIEW CumulativeVaccinationView AS
SELECT cd.continent, cd.location, cd.date, cd.population, cv.new_vaccinations,
       SUM(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) as cumulative_vaccinations,
       (CAST(SUM(CAST(COALESCE(cv.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY cv.location ORDER BY cd.date) AS float) / CAST(cd.population AS float)) * 100 as vaccination_percentage
FROM CovidDeaths as cd
JOIN CovidVaccinations as cv
ON cd.location = cv.location
AND cd.date = cv.date
WHERE cd.continent IS not NULL;
-- Query the view in a new batch
SELECT * FROM CumulativeVaccinationView
ORDER BY location, date;
