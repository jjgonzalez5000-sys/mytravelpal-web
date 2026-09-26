"""Curated top-selling EU car models with real-world tank size and
consumption figures.

Motivation: the plan flow needs tank size + consumption to compute a
useful "refuel within N km" hint. Manual sliders in the profile screen
work for enthusiasts but 99 % of drivers don't know their tank in
litres. Picking their model from a list resolves both fields without
homework.

Numbers are best-effort, tuned to REAL-WORLD figures (ADAC /
Spritmonitor community averages), not WLTP or NEDC. Rule of thumb:
WLTP × ~1.15 to 1.20 lands close to real usage on mixed European
roads. Tank capacities come from the manufacturers' spec sheets.

If a model has multiple engines (petrol / diesel / HEV / PHEV) that
matter for the fuel-cost estimation, we ship one entry per engine so
the picker surfaces the right consumption. IDs are stable strings —
they land in the user's persisted profile so renaming them breaks
older installs.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain import FuelType


@dataclass(frozen=True, slots=True)
class VehicleModel:
    """A single vehicle variant curated for the picker.

    - `year_from` / `year_to`: production window. `year_to = None`
      means "still in production". Displayed as "2019+" or
      "2015-2020". Used only for the label; the tank + consumption
      figures apply across the whole window.
    - `tank_liters`: spec-sheet fuel tank size. For HEV models this
      is the petrol tank (battery is transparent to the driver).
    - `consumption_l100km`: real-world combined-cycle consumption
      (L/100km). For HEV variants this is the effective petrol figure
      most drivers see (battery regen already baked in).
    """

    id: str
    make: str
    model: str
    year_from: int
    year_to: int | None
    fuel_type: FuelType
    tank_liters: float
    consumption_l100km: float

    def label(self) -> str:
        """Human-readable label, e.g. `Golf 8 · 2019+ · Petrol · 50 L · 6.5 L/100km`."""
        year_range = (
            f"{self.year_from}+"
            if self.year_to is None
            else f"{self.year_from}-{self.year_to}"
        )
        return (
            f"{self.model} · {year_range} · {self.fuel_type.value} · "
            f"{self.tank_liters:.0f} L · {self.consumption_l100km:.1f} L/100km"
        )


VEHICLE_MODELS: tuple[VehicleModel, ...] = (
    # -- Volkswagen ------------------------------------------------------
    VehicleModel("vw_polo_6", "Volkswagen", "Polo 6",
                 2017, None, FuelType.PETROL, 40, 6.0),
    VehicleModel("vw_polo_6_diesel", "Volkswagen", "Polo 6",
                 2017, None, FuelType.DIESEL, 40, 4.7),
    VehicleModel("vw_golf_8", "Volkswagen", "Golf 8",
                 2019, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("vw_golf_8_diesel", "Volkswagen", "Golf 8",
                 2019, None, FuelType.DIESEL, 50, 5.2),
    VehicleModel("vw_troc", "Volkswagen", "T-Roc",
                 2017, None, FuelType.PETROL, 50, 7.0),
    VehicleModel("vw_troc_diesel", "Volkswagen", "T-Roc",
                 2017, None, FuelType.DIESEL, 50, 5.5),
    VehicleModel("vw_tiguan_2", "Volkswagen", "Tiguan 2",
                 2016, None, FuelType.PETROL, 58, 7.8),
    VehicleModel("vw_tiguan_2_diesel", "Volkswagen", "Tiguan 2",
                 2016, None, FuelType.DIESEL, 58, 6.0),
    VehicleModel("vw_passat_b8", "Volkswagen", "Passat B8",
                 2014, 2023, FuelType.DIESEL, 66, 5.6),
    # -- SEAT / CUPRA ----------------------------------------------------
    VehicleModel("seat_ibiza_5", "SEAT", "Ibiza 5",
                 2017, None, FuelType.PETROL, 40, 5.9),
    VehicleModel("seat_leon_4", "SEAT", "León 4",
                 2020, None, FuelType.PETROL, 45, 6.4),
    VehicleModel("seat_leon_4_diesel", "SEAT", "León 4",
                 2020, None, FuelType.DIESEL, 45, 5.0),
    VehicleModel("seat_arona", "SEAT", "Arona",
                 2017, None, FuelType.PETROL, 40, 6.4),
    VehicleModel("seat_ateca", "SEAT", "Ateca",
                 2016, None, FuelType.PETROL, 55, 7.2),
    VehicleModel("cupra_formentor", "CUPRA", "Formentor",
                 2020, None, FuelType.PETROL, 55, 7.5),
    # -- Renault / Dacia -------------------------------------------------
    VehicleModel("renault_clio_5", "Renault", "Clio 5",
                 2019, None, FuelType.PETROL, 42, 5.8),
    VehicleModel("renault_clio_5_hybrid", "Renault", "Clio 5 E-Tech",
                 2020, None, FuelType.HYBRID, 39, 4.5),
    VehicleModel("renault_captur_2", "Renault", "Captur 2",
                 2019, None, FuelType.PETROL, 48, 6.5),
    VehicleModel("renault_megane_4", "Renault", "Mégane 4",
                 2015, 2022, FuelType.DIESEL, 47, 5.1),
    VehicleModel("dacia_sandero_3", "Dacia", "Sandero 3",
                 2020, None, FuelType.PETROL, 50, 6.0),
    VehicleModel("dacia_sandero_3_lpg", "Dacia", "Sandero 3 ECO-G",
                 2020, None, FuelType.LPG, 50, 7.6),
    VehicleModel("dacia_duster_2", "Dacia", "Duster 2",
                 2018, None, FuelType.PETROL, 50, 7.2),
    VehicleModel("dacia_duster_2_lpg", "Dacia", "Duster 2 ECO-G",
                 2018, None, FuelType.LPG, 50, 8.6),
    # -- Peugeot / Citroen / Opel (Stellantis) --------------------------
    VehicleModel("peugeot_208_ii", "Peugeot", "208 II",
                 2019, None, FuelType.PETROL, 44, 6.0),
    VehicleModel("peugeot_2008_ii", "Peugeot", "2008 II",
                 2019, None, FuelType.PETROL, 44, 6.4),
    VehicleModel("peugeot_3008_ii", "Peugeot", "3008 II",
                 2016, None, FuelType.DIESEL, 53, 5.5),
    VehicleModel("peugeot_308_iii", "Peugeot", "308 III",
                 2021, None, FuelType.PETROL, 52, 6.6),
    VehicleModel("citroen_c3_iii", "Citroën", "C3 III",
                 2016, None, FuelType.PETROL, 45, 6.2),
    VehicleModel("citroen_c4_iii", "Citroën", "C4 III",
                 2020, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("opel_corsa_f", "Opel", "Corsa F",
                 2019, None, FuelType.PETROL, 40, 5.8),
    VehicleModel("opel_astra_l", "Opel", "Astra L",
                 2021, None, FuelType.PETROL, 52, 6.3),
    VehicleModel("fiat_panda_iii", "Fiat", "Panda III",
                 2011, None, FuelType.PETROL, 37, 6.0),
    VehicleModel("fiat_500", "Fiat", "500",
                 2007, 2023, FuelType.PETROL, 35, 5.5),
    # -- Ford ------------------------------------------------------------
    VehicleModel("ford_puma", "Ford", "Puma",
                 2019, None, FuelType.PETROL, 42, 6.4),
    VehicleModel("ford_focus_iv", "Ford", "Focus IV",
                 2018, None, FuelType.PETROL, 52, 6.6),
    VehicleModel("ford_kuga_iii", "Ford", "Kuga III",
                 2019, None, FuelType.PETROL, 54, 7.4),
    # -- Toyota ----------------------------------------------------------
    VehicleModel("toyota_yaris_4", "Toyota", "Yaris 4",
                 2020, None, FuelType.PETROL, 40, 5.6),
    VehicleModel("toyota_yaris_4_hev", "Toyota", "Yaris 4 Hybrid",
                 2020, None, FuelType.HYBRID, 36, 4.2),
    VehicleModel("toyota_corolla_e210", "Toyota", "Corolla E210",
                 2018, None, FuelType.PETROL, 43, 6.4),
    VehicleModel("toyota_corolla_e210_hev", "Toyota", "Corolla E210 Hybrid",
                 2018, None, FuelType.HYBRID, 43, 4.6),
    VehicleModel("toyota_rav4_v", "Toyota", "RAV4 V",
                 2018, None, FuelType.HYBRID, 55, 5.5),
    VehicleModel("toyota_chr_2", "Toyota", "C-HR 2",
                 2023, None, FuelType.HYBRID, 43, 4.9),
    # -- Hyundai / Kia ---------------------------------------------------
    VehicleModel("hyundai_i30_iii", "Hyundai", "i30 III",
                 2016, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("hyundai_tucson_nx4", "Hyundai", "Tucson NX4",
                 2020, None, FuelType.PETROL, 54, 7.2),
    VehicleModel("hyundai_tucson_nx4_hev", "Hyundai", "Tucson NX4 Hybrid",
                 2020, None, FuelType.HYBRID, 54, 5.8),
    VehicleModel("kia_ceed_iii", "Kia", "Ceed III",
                 2018, None, FuelType.PETROL, 50, 6.4),
    VehicleModel("kia_sportage_v", "Kia", "Sportage V",
                 2021, None, FuelType.PETROL, 54, 7.4),
    VehicleModel("kia_niro_ii_hev", "Kia", "Niro II Hybrid",
                 2022, None, FuelType.HYBRID, 42, 5.0),
    # -- Others (BMW / Audi / Mercedes / Skoda / Nissan) -----------------
    VehicleModel("skoda_octavia_iv", "Skoda", "Octavia IV",
                 2020, None, FuelType.DIESEL, 45, 5.0),
    VehicleModel("skoda_fabia_iv", "Skoda", "Fabia IV",
                 2021, None, FuelType.PETROL, 42, 6.0),
    VehicleModel("nissan_qashqai_j12", "Nissan", "Qashqai J12",
                 2021, None, FuelType.PETROL, 55, 7.1),
    VehicleModel("bmw_serie_1_f40", "BMW", "Serie 1 F40",
                 2019, None, FuelType.PETROL, 42, 6.7),
    VehicleModel("audi_a3_8y", "Audi", "A3 8Y",
                 2020, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("mercedes_a_w177", "Mercedes-Benz", "Clase A W177",
                 2018, None, FuelType.PETROL, 43, 6.8),
)


_BY_ID: dict[str, VehicleModel] = {v.id: v for v in VEHICLE_MODELS}


def all_models() -> tuple[VehicleModel, ...]:
    return VEHICLE_MODELS


def find(model_id: str) -> VehicleModel | None:
    return _BY_ID.get(model_id)
