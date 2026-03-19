from __future__ import annotations

import re
from pathlib import Path

import pandas as pd


BASE_DIR = Path(r"C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source")
SALES_DIR = BASE_DIR / r"PBI A10P C07A IT SP GR\star_schema_sales"
PROMO_DIR = BASE_DIR / r"PBI A10P C7A IT SP GR - Channel Dynamics\star_schema_promotionl"
FINANCE_DIR = BASE_DIR / r"PBI Cana Finance\star_schema_finance_int"
OUTPUT_DIR = BASE_DIR / r"Integrated Product Analysis Core\semantic_source"
REPORT_PATH = BASE_DIR / r"Integrated Product Analysis Core\integration_source_report.md"


ATC4_DESCRIPTION_BY_CODE = {
    "A10P1": "SGLT2 INHIB A-DIAB PLAIN",
    "A10P3": "SGLT2 INHIB A-DIAB COMB",
}

FINANCE_PORTFOLIO_BY_MOLECULE = {
    "CANAGLIFLOZIN": ("A10P1", "INVOKANA"),
    "CANAGLIFLOZIN + METFORMIN": ("A10P3", "VOKANAMET"),
}


def normalize_text(value: object) -> str:
    if pd.isna(value):
        return ""
    text = str(value).upper().strip()
    text = text.replace("’", "'")
    text = text.replace(">", " ")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def normalize_country_name(value: object) -> str:
    code = normalize_text(value)
    mapping = {
        "IT": "Italy",
        "ES": "Spain",
        "GR": "Greece",
        "ITALY": "Italy",
        "SPAIN": "Spain",
        "GREECE": "Greece",
    }
    return mapping.get(code, str(value).title() if value else "")


def normalize_corporation(value: object) -> str:
    text = normalize_text(value)
    if "GUIDOTTI" in text or "MENARINI" in text:
        return "MENARINI"
    return text


def normalize_sales_brand(value: object) -> str:
    raw = "" if pd.isna(value) else str(value).upper().strip()
    if ">>" in raw:
        raw = re.split(r"\s{2,}", raw)[0]
    raw = raw.replace(">", " ")
    raw = re.sub(r"\s+", " ", raw)
    return raw.strip()


def normalize_molecule_combo(value: object) -> str:
    text = normalize_text(value)
    text = text.replace("!", "+").replace(",", "+").replace(";", "+").replace("/", "+")
    text = text.replace("CANAGLIFOZIN", "CANAGLIFLOZIN")
    parts = [part.strip() for part in re.split(r"\+", text) if part.strip()]
    parts = [part for part in parts if part != "NOT CODED"]
    parts = sorted(dict.fromkeys(parts))
    return " + ".join(parts)


def build_country_dimension(
    sales_country: pd.DataFrame,
    promo_country: pd.DataFrame,
    finance_country: pd.DataFrame,
) -> tuple[pd.DataFrame, dict[str, int]]:
    country_codes = sorted(
        set(sales_country["country_code"])
        | set(promo_country["country_code"])
        | set(finance_country["country_code"])
    )
    sort_order = {"IT": 1, "ES": 2, "GR": 3}
    rows = []
    for code in sorted(country_codes, key=lambda value: sort_order.get(value, 999)):
        rows.append(
            {
                "country_key": sort_order.get(code, len(rows) + 1),
                "country_code": code,
                "country_name": normalize_country_name(code if code != "GR" else "GREECE"),
            }
        )
    country_df = pd.DataFrame(rows)
    country_key_by_code = dict(zip(country_df["country_code"], country_df["country_key"]))
    return country_df, country_key_by_code


def build_quarter_dimension(
    sales_quarter: pd.DataFrame,
    promo_reporting: pd.DataFrame,
    finance_month: pd.DataFrame,
) -> pd.DataFrame:
    sales_seed = sales_quarter[["year", "quarter_number"]].drop_duplicates()
    promo_seed = promo_reporting[["quarter_year", "quarter_number"]].drop_duplicates().rename(
        columns={"quarter_year": "year"}
    )
    finance_seed = finance_month[["year", "quarter_number"]].drop_duplicates()

    quarter_union = (
        pd.concat([sales_seed, promo_seed, finance_seed], ignore_index=True)
        .drop_duplicates()
        .sort_values(["year", "quarter_number"])
        .reset_index(drop=True)
    )

    quarter_union["quarter_key"] = quarter_union["year"] * 10 + quarter_union["quarter_number"]
    quarter_union["quarter_date"] = pd.to_datetime(
        dict(
            year=quarter_union["year"],
            month=(quarter_union["quarter_number"] * 3) - 2,
            day=1,
        )
    )
    quarter_union["quarter_label"] = (
        "Q"
        + quarter_union["quarter_number"].astype(str)
        + " "
        + quarter_union["year"].astype(str)
    )
    quarter_union["calendar_quarter"] = quarter_union["quarter_label"]
    quarter_union["year_quarter"] = (
        quarter_union["year"].astype(str)
        + "-Q"
        + quarter_union["quarter_number"].astype(str)
    )
    quarter_union["month_number"] = (quarter_union["quarter_number"] * 3) - 2
    quarter_union["quarter_sort_key"] = quarter_union["quarter_key"]
    quarter_union["is_common_three_worlds"] = quarter_union["quarter_key"].between(20241, 20253)

    return quarter_union[
        [
            "quarter_key",
            "quarter_date",
            "quarter_label",
            "calendar_quarter",
            "year",
            "quarter_number",
            "month_number",
            "year_quarter",
            "quarter_sort_key",
            "is_common_three_worlds",
        ]
    ]


def build_month_dimension(finance_month: pd.DataFrame) -> pd.DataFrame:
    month_df = finance_month.copy()
    month_df["quarter_key"] = month_df["year"] * 10 + month_df["quarter_number"]
    month_df["month_date"] = pd.to_datetime(month_df["month_date"], dayfirst=True)
    return month_df[
        [
            "month_key",
            "month_date",
            "month_label",
            "year",
            "month_number",
            "year_month",
            "month_sort_key",
            "quarter_number",
            "year_quarter",
            "quarter_key",
        ]
    ].sort_values("month_key")


def build_portfolio_and_products(
    sales_product: pd.DataFrame,
    promo_product: pd.DataFrame,
    finance_product: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    promo = promo_product.copy()
    promo["corporation_group"] = promo["int_corporation_name"].map(normalize_corporation)
    promo["molecule_norm"] = promo["molecule_combo"].map(normalize_molecule_combo)
    promo["portfolio_name"] = promo["local_brand_name"].map(normalize_text)
    promo["portfolio_key_nk"] = (
        promo["atc4_code"].astype(str)
        + "|"
        + promo["corporation_group"]
        + "|"
        + promo["portfolio_name"]
        + "|"
        + promo["molecule_norm"]
    )

    promo_groups: dict[tuple[str, str, str], set[str]] = {}
    for row in promo.itertuples():
        key = (row.atc4_code, row.corporation_group, row.molecule_norm)
        promo_groups.setdefault(key, set()).add(row.portfolio_name)

    sales = sales_product.copy()
    sales["brand_clean"] = sales["product_name"].map(normalize_sales_brand)
    sales["corporation_group"] = sales["corporation_name"].map(normalize_corporation)
    sales["molecule_norm"] = sales["molecule_list"].map(normalize_molecule_combo)
    sales["portfolio_name"] = sales["brand_clean"].map(normalize_text)

    def map_sales_portfolio(row: pd.Series) -> str:
        choices = promo_groups.get((row["atc4_code"], row["corporation_group"], row["molecule_norm"]), set())
        for choice in sorted(choices, key=len, reverse=True):
            if row["portfolio_name"].startswith(choice) or choice.startswith(row["portfolio_name"]):
                return choice
        return row["portfolio_name"]

    sales["portfolio_name"] = sales.apply(map_sales_portfolio, axis=1)
    sales["portfolio_key_nk"] = (
        sales["atc4_code"].astype(str)
        + "|"
        + sales["corporation_group"]
        + "|"
        + sales["portfolio_name"]
        + "|"
        + sales["molecule_norm"]
    )

    finance = finance_product.copy()
    finance["corporation_group"] = finance["corporation_group"].map(normalize_corporation)
    finance["molecule_norm"] = finance["molecule_desc_raw"].map(normalize_molecule_combo)
    finance["atc4_code"] = finance["molecule_norm"].map(
        lambda value: FINANCE_PORTFOLIO_BY_MOLECULE.get(value, ("", ""))[0]
    )
    finance["portfolio_name"] = finance["molecule_norm"].map(
        lambda value: FINANCE_PORTFOLIO_BY_MOLECULE.get(value, ("", normalize_text(value)))[1]
    )
    finance["atc4_description"] = finance["atc4_code"].map(ATC4_DESCRIPTION_BY_CODE).fillna("")
    finance["portfolio_key_nk"] = (
        finance["atc4_code"].astype(str)
        + "|"
        + finance["corporation_group"]
        + "|"
        + finance["portfolio_name"]
        + "|"
        + finance["molecule_norm"]
    )

    portfolio_seed = pd.concat(
        [
            sales[
                [
                    "portfolio_key_nk",
                    "portfolio_name",
                    "atc4_raw",
                    "atc4_code",
                    "atc4_description",
                    "corporation_group",
                    "molecule_norm",
                    "molecule_count",
                    "is_combo_molecule",
                ]
            ].assign(has_sales=True, has_promo=False, has_finance=False),
            promo[
                [
                    "portfolio_key_nk",
                    "portfolio_name",
                    "atc4_raw",
                    "atc4_code",
                    "atc4_description",
                    "corporation_group",
                    "molecule_norm",
                    "molecule_count",
                    "is_combo_molecule",
                ]
            ].assign(has_sales=False, has_promo=True, has_finance=False),
            finance[
                [
                    "portfolio_key_nk",
                    "portfolio_name",
                    "atc4_code",
                    "atc4_description",
                    "corporation_group",
                    "molecule_norm",
                    "molecule_count",
                    "is_combo_molecule",
                ]
            ]
            .assign(atc4_raw=lambda df: df["atc4_code"] + " - " + df["atc4_description"])
            .assign(has_sales=False, has_promo=False, has_finance=True),
        ],
        ignore_index=True,
    )

    portfolio = (
        portfolio_seed.groupby("portfolio_key_nk", as_index=False)
        .agg(
            portfolio_name=("portfolio_name", "first"),
            atc4_raw=("atc4_raw", "first"),
            atc4_code=("atc4_code", "first"),
            atc4_description=("atc4_description", "first"),
            corporation_group=("corporation_group", "first"),
            molecule_list=("molecule_norm", "first"),
            molecule_count=("molecule_count", "max"),
            is_combo_molecule=("is_combo_molecule", "max"),
            has_sales=("has_sales", "max"),
            has_promo=("has_promo", "max"),
            has_finance=("has_finance", "max"),
        )
        .sort_values(["atc4_code", "corporation_group", "portfolio_name", "molecule_list"])
        .reset_index(drop=True)
    )
    portfolio["portfolio_key"] = range(1, len(portfolio) + 1)
    portfolio["is_common_three_worlds"] = (
        portfolio["has_sales"] & portfolio["has_promo"] & portfolio["has_finance"]
    )

    portfolio_key_by_nk = dict(zip(portfolio["portfolio_key_nk"], portfolio["portfolio_key"]))

    sales_out = sales.copy()
    sales_out["portfolio_key"] = sales_out["portfolio_key_nk"].map(portfolio_key_by_nk)
    sales_out["product_label"] = sales_out["product_name"].map(normalize_text)
    sales_out = sales_out[
        [
            "product_key",
            "portfolio_key",
            "product_label",
            "product_name",
            "pack_name",
            "corporation_name",
            "corporation_group",
            "atc4_raw",
            "atc4_code",
            "atc4_description",
            "molecule_list",
            "molecule_count",
            "is_combo_molecule",
            "protection_current",
            "international_prescription",
        ]
    ].sort_values("product_key")

    promo_out = promo.copy()
    promo_out["portfolio_key"] = promo_out["portfolio_key_nk"].map(portfolio_key_by_nk)
    promo_out["product_label"] = promo_out["local_brand_name"].map(normalize_text)
    promo_out = promo_out[
        [
            "product_key",
            "portfolio_key",
            "product_label",
            "local_brand_name",
            "int_corporation_name",
            "corporation_group",
            "atc4_raw",
            "atc4_code",
            "atc4_description",
            "molecule_combo",
            "molecule_count",
            "is_combo_molecule",
            "has_not_coded_molecule",
        ]
    ].sort_values("product_key")

    finance_out = finance.copy()
    finance_out["portfolio_key"] = finance_out["portfolio_key_nk"].map(portfolio_key_by_nk)
    finance_out["product_label"] = finance_out["portfolio_name"]
    finance_out = finance_out[
        [
            "product_key",
            "portfolio_key",
            "product_label",
            "molecule_desc_raw",
            "company_desc",
            "corporation_group",
            "atc4_code",
            "atc4_description",
            "molecule_norm",
            "molecule_count",
            "is_combo_molecule",
        ]
    ].rename(columns={"molecule_norm": "molecule_list"}).sort_values("product_key")

    molecule_names = sorted(
        {
            molecule
            for molecule_list in portfolio["molecule_list"]
            for molecule in [part.strip() for part in str(molecule_list).split(" + ")]
            if molecule
        }
    )
    molecule = pd.DataFrame(
        {
            "molecule_key": range(1, len(molecule_names) + 1),
            "molecule_name": molecule_names,
        }
    )
    molecule_key_by_name = dict(zip(molecule["molecule_name"], molecule["molecule_key"]))

    bridge_rows = []
    for row in portfolio.itertuples():
        for position, molecule_name in enumerate(row.molecule_list.split(" + "), start=1):
            if molecule_name:
                bridge_rows.append(
                    {
                        "portfolio_key": row.portfolio_key,
                        "molecule_key": molecule_key_by_name[molecule_name],
                        "molecule_position": position,
                    }
                )
    bridge = pd.DataFrame(bridge_rows).sort_values(["portfolio_key", "molecule_position"])

    portfolio_out = portfolio[
        [
            "portfolio_key",
            "portfolio_name",
            "atc4_raw",
            "atc4_code",
            "atc4_description",
            "corporation_group",
            "molecule_list",
            "molecule_count",
            "is_combo_molecule",
            "has_sales",
            "has_promo",
            "has_finance",
            "is_common_three_worlds",
        ]
    ]

    return portfolio_out, molecule, bridge, sales_out, promo_out, finance_out


def build_sales_fact(
    sales_fact: pd.DataFrame,
    sales_country: pd.DataFrame,
    sales_quarter: pd.DataFrame,
    country_key_by_code: dict[str, int],
) -> pd.DataFrame:
    sales_country_lookup = dict(zip(sales_country["country_key"], sales_country["country_code"]))
    sales_quarter_lookup = (
        sales_quarter.assign(quarter_key=lambda df: df["year"] * 10 + df["quarter_number"])
        .set_index("date_key")["quarter_key"]
        .to_dict()
    )

    fact = sales_fact.copy()
    fact["country_code"] = fact["country_key"].map(sales_country_lookup)
    fact["country_key"] = fact["country_code"].map(country_key_by_code)
    fact["quarter_key"] = fact["date_key"].map(sales_quarter_lookup)
    fact = fact.rename(columns={"date_key": "source_date_key"})
    return fact[
        [
            "fact_key",
            "country_key",
            "quarter_key",
            "sector_key",
            "diagnosis_key",
            "product_key",
            "units",
            "counting_units",
            "eur_mnf",
        ]
    ].sort_values("fact_key")


def build_promo_fact(
    promo_fact: pd.DataFrame,
    promo_country: pd.DataFrame,
    promo_reporting: pd.DataFrame,
    country_key_by_code: dict[str, int],
) -> pd.DataFrame:
    promo_country_lookup = dict(zip(promo_country["country_key"], promo_country["country_code"]))

    reporting = promo_reporting.copy()
    reporting["quarter_key"] = reporting["quarter_year"] * 10 + reporting["quarter_number"]
    latest_reporting = (
        reporting.sort_values(["calendar_quarter_sort_key", "snapshot_date_key"])
        .groupby("calendar_quarter", as_index=False)
        .tail(1)
    )
    latest_reporting_keys = set(latest_reporting["reporting_period_key"])
    quarter_lookup = latest_reporting.set_index("reporting_period_key")["quarter_key"].to_dict()

    fact = promo_fact[promo_fact["reporting_period_key"].isin(latest_reporting_keys)].copy()
    fact["country_code"] = fact["country_key"].map(promo_country_lookup)
    fact["country_key"] = fact["country_code"].map(country_key_by_code)
    fact["quarter_key"] = fact["reporting_period_key"].map(quarter_lookup)
    return fact[
        [
            "fact_key",
            "country_key",
            "quarter_key",
            "product_key",
            "specialty_key",
            "channel_key",
            "feedback_key",
            "product_details",
            "contact_number",
            "mentions",
            "weighted_calls",
            "spending_total_eur",
            "quality_index",
            "converted_contacts",
        ]
    ].sort_values("fact_key")


def build_finance_fact(
    finance_fact: pd.DataFrame,
    finance_country: pd.DataFrame,
    country_key_by_code: dict[str, int],
) -> pd.DataFrame:
    finance_country_lookup = dict(zip(finance_country["country_key"], finance_country["country_code"]))
    fact = finance_fact.copy()
    fact["country_code"] = fact["country_key"].map(finance_country_lookup)
    fact["country_key"] = fact["country_code"].map(country_key_by_code)
    return fact[
        [
            "fact_key",
            "country_key",
            "month_key",
            "product_key",
            "act_mth",
            "bdg_mth",
        ]
    ].sort_values("fact_key")


def write_csv(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = df.copy()
    for column in output.columns:
        if pd.api.types.is_datetime64_any_dtype(output[column]):
            output[column] = output[column].dt.strftime("%d/%m/%Y")
    output.to_csv(path, index=False)


def build_report(
    country_df: pd.DataFrame,
    quarter_df: pd.DataFrame,
    month_df: pd.DataFrame,
    portfolio_df: pd.DataFrame,
    sales_fact_df: pd.DataFrame,
    promo_fact_df: pd.DataFrame,
    finance_fact_df: pd.DataFrame,
) -> str:
    common_portfolio = portfolio_df[portfolio_df["is_common_three_worlds"]]["portfolio_name"].tolist()
    lines = [
        "# Integrated Product Analysis Core Source",
        "",
        "## Scope",
        "",
        "Questa cartella contiene la base dati integrata per il semantic model cross-world dei tre mondi legacy:",
        "",
        "- Sales",
        "- Promo",
        "- Finance interno",
        "",
        "L'integrazione mantiene le fact separate e crea una identita' condivisa tramite dimensioni conformate.",
        "",
        "## Output",
        "",
        f"- Country conformed rows: `{len(country_df)}`",
        f"- Quarter conformed rows: `{len(quarter_df)}`",
        f"- Month rows: `{len(month_df)}`",
        f"- Portfolio conformed rows: `{len(portfolio_df)}`",
        f"- Sales fact rows: `{len(sales_fact_df)}`",
        f"- Promo fact rows: `{len(promo_fact_df)}`",
        f"- Finance fact rows: `{len(finance_fact_df)}`",
        "",
        "## Integrated Identity",
        "",
        "- Country comune: `Country`",
        "- Tempo comune cross-world: `Quarter`",
        "- Tempo finance detail: `Month`",
        "- Identita' portfolio comune: `Portfolio`",
        "- Identita' molecolare comune: `Molecule`",
        "",
        "## Common 3-World Perimeter",
        "",
        "- Country: `Italy`",
        "- Quarter comune affidabile: `2024Q1 -> 2025Q3`",
        "- Portfolio comune reale: `" + "`, `".join(common_portfolio) + "`" if common_portfolio else "- Portfolio comune reale: n/a",
        "",
        "## Technical Notes",
        "",
        "- Promo viene materializzato sul latest snapshot disponibile per ciascun calendar quarter.",
        "- Finance mantiene la grain mensile, ma viene collegato al quarter tramite `Month -> Quarter`.",
        "- La dimensione `Portfolio` conforma Sales, Promo e Finance a livello brand / portfolio business.",
        "- La normalizzazione molecolare corregge la differenza `CANAGLIFOZIN -> CANAGLIFLOZIN`.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    sales_country = pd.read_csv(SALES_DIR / "dim_country.csv")
    sales_quarter = pd.read_csv(SALES_DIR / "dim_date_quarter.csv")
    sales_product = pd.read_csv(SALES_DIR / "dim_product.csv")
    sales_sector = pd.read_csv(SALES_DIR / "dim_sector.csv")
    sales_diagnosis = pd.read_csv(SALES_DIR / "dim_diagnosis.csv")
    sales_fact = pd.read_csv(SALES_DIR / "fact_market_performance_quarterly.csv")

    promo_country = pd.read_csv(PROMO_DIR / "dim_country.csv")
    promo_reporting = pd.read_csv(PROMO_DIR / "dim_reporting_period.csv")
    promo_product = pd.read_csv(PROMO_DIR / "dim_product.csv")
    promo_specialty = pd.read_csv(PROMO_DIR / "dim_specialty.csv")
    promo_channel = pd.read_csv(PROMO_DIR / "dim_channel.csv")
    promo_feedback = pd.read_csv(PROMO_DIR / "dim_feedback_profile.csv")
    promo_fact = pd.read_csv(PROMO_DIR / "fact_channel_dynamics_monthly.csv")

    finance_country = pd.read_csv(FINANCE_DIR / "dim_country.csv")
    finance_month = pd.read_csv(FINANCE_DIR / "dim_month.csv")
    finance_product = pd.read_csv(FINANCE_DIR / "dim_product.csv")
    finance_fact = pd.read_csv(FINANCE_DIR / "fact_cana_finance_monthly.csv")

    country_df, country_key_by_code = build_country_dimension(
        sales_country,
        promo_country,
        finance_country,
    )
    quarter_df = build_quarter_dimension(sales_quarter, promo_reporting, finance_month)
    month_df = build_month_dimension(finance_month)
    (
        portfolio_df,
        molecule_df,
        portfolio_molecule_df,
        sales_product_df,
        promo_product_df,
        finance_product_df,
    ) = build_portfolio_and_products(sales_product, promo_product, finance_product)
    sales_fact_df = build_sales_fact(sales_fact, sales_country, sales_quarter, country_key_by_code)
    promo_fact_df = build_promo_fact(promo_fact, promo_country, promo_reporting, country_key_by_code)
    finance_fact_df = build_finance_fact(finance_fact, finance_country, country_key_by_code)

    write_csv(country_df, OUTPUT_DIR / "dim_country.csv")
    write_csv(quarter_df, OUTPUT_DIR / "dim_quarter.csv")
    write_csv(month_df, OUTPUT_DIR / "dim_month.csv")
    write_csv(portfolio_df, OUTPUT_DIR / "dim_portfolio.csv")
    write_csv(molecule_df, OUTPUT_DIR / "dim_molecule.csv")
    write_csv(portfolio_molecule_df, OUTPUT_DIR / "bridge_portfolio_molecule.csv")
    write_csv(sales_product_df, OUTPUT_DIR / "dim_sales_product.csv")
    write_csv(promo_product_df, OUTPUT_DIR / "dim_promo_product.csv")
    write_csv(finance_product_df, OUTPUT_DIR / "dim_finance_product.csv")
    write_csv(sales_sector, OUTPUT_DIR / "dim_sector.csv")
    write_csv(sales_diagnosis, OUTPUT_DIR / "dim_diagnosis.csv")
    write_csv(promo_specialty, OUTPUT_DIR / "dim_specialty.csv")
    write_csv(promo_channel, OUTPUT_DIR / "dim_channel.csv")
    write_csv(promo_feedback, OUTPUT_DIR / "dim_feedback.csv")
    write_csv(sales_fact_df, OUTPUT_DIR / "fact_sales.csv")
    write_csv(promo_fact_df, OUTPUT_DIR / "fact_promo.csv")
    write_csv(finance_fact_df, OUTPUT_DIR / "fact_finance.csv")

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        build_report(
            country_df,
            quarter_df,
            month_df,
            portfolio_df,
            sales_fact_df,
            promo_fact_df,
            finance_fact_df,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
