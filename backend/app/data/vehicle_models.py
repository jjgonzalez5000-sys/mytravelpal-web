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
    # ICE fields (petrol / diesel / hybrid). Left as 0 for pure EVs.
    tank_liters: float
    consumption_l100km: float
    # EV fields (electric). Left as 0 for ICE. WLTP → real-world:
    # real_range ≈ WLTP × 0.80 on mixed routes; consumption includes
    # ~10 % charging loss so kWh figures match wall-plug spend.
    battery_kwh: float = 0.0
    ev_range_km: float = 0.0
    consumption_kwh100km: float = 0.0

    def label(self) -> str:
        """Human-readable label."""
        year_range = (
            f"{self.year_from}+"
            if self.year_to is None
            else f"{self.year_from}-{self.year_to}"
        )
        if self.fuel_type == FuelType.ELECTRIC:
            return (
                f"{self.model} · {year_range} · {self.fuel_type.value} · "
                f"{self.battery_kwh:.0f} kWh · "
                f"{self.consumption_kwh100km:.1f} kWh/100km · "
                f"~{self.ev_range_km:.0f} km"
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
    # -- Additional ICE (top EU sellers previously missing) --------------
    VehicleModel("toyota_aygo_x", "Toyota", "Aygo X",
                 2022, None, FuelType.PETROL, 35, 4.9),
    VehicleModel("toyota_yaris_cross", "Toyota", "Yaris Cross Hybrid",
                 2021, None, FuelType.HYBRID, 36, 4.5),
    VehicleModel("toyota_chr_2_hev", "Toyota", "C-HR 2 Hybrid",
                 2023, None, FuelType.HYBRID, 43, 4.9),
    VehicleModel("peugeot_3008_ii_hybrid", "Peugeot", "3008 II Hybrid",
                 2019, None, FuelType.HYBRID, 43, 5.4),
    VehicleModel("renault_captur_2_hybrid", "Renault", "Captur 2 E-Tech",
                 2020, None, FuelType.HYBRID, 39, 4.8),
    VehicleModel("audi_q3_f3", "Audi", "Q3 F3",
                 2018, None, FuelType.PETROL, 58, 7.2),
    VehicleModel("audi_q5_fy", "Audi", "Q5 FY",
                 2016, None, FuelType.DIESEL, 65, 6.5),
    VehicleModel("bmw_serie_3_g20", "BMW", "Serie 3 G20",
                 2018, None, FuelType.PETROL, 59, 6.9),
    VehicleModel("bmw_serie_3_g20_diesel", "BMW", "Serie 3 G20",
                 2018, None, FuelType.DIESEL, 59, 5.4),
    VehicleModel("mercedes_cla_c118", "Mercedes-Benz", "CLA C118",
                 2019, None, FuelType.PETROL, 51, 6.8),
    VehicleModel("mercedes_gla_h247", "Mercedes-Benz", "GLA H247",
                 2020, None, FuelType.PETROL, 50, 7.4),
    VehicleModel("volvo_xc40", "Volvo", "XC40",
                 2017, None, FuelType.PETROL, 54, 7.0),
    VehicleModel("mazda_cx5_kf", "Mazda", "CX-5 KF",
                 2017, None, FuelType.PETROL, 58, 7.4),
    VehicleModel("mazda_3_bp", "Mazda", "3 BP",
                 2019, None, FuelType.PETROL, 51, 6.4),
    VehicleModel("citroen_c5_aircross", "Citroën", "C5 Aircross",
                 2018, None, FuelType.PETROL, 53, 7.1),
    VehicleModel("skoda_karoq", "Skoda", "Karoq",
                 2017, None, FuelType.PETROL, 55, 6.9),
    VehicleModel("skoda_kodiaq", "Skoda", "Kodiaq",
                 2016, None, FuelType.DIESEL, 60, 6.4),
    VehicleModel("hyundai_kona", "Hyundai", "Kona",
                 2017, None, FuelType.PETROL, 50, 6.8),
    VehicleModel("kia_stonic", "Kia", "Stonic",
                 2017, None, FuelType.PETROL, 45, 6.4),
    VehicleModel("ford_fiesta_mk8", "Ford", "Fiesta Mk8",
                 2017, 2023, FuelType.PETROL, 42, 5.5),
    VehicleModel("opel_mokka_b", "Opel", "Mokka B",
                 2020, None, FuelType.PETROL, 44, 6.6),
    VehicleModel("mini_cooper_f56", "MINI", "Cooper F56",
                 2014, None, FuelType.PETROL, 44, 6.2),
    VehicleModel("fiat_tipo", "Fiat", "Tipo",
                 2015, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("suzuki_swift", "Suzuki", "Swift",
                 2017, None, FuelType.PETROL, 37, 5.2),
    VehicleModel("suzuki_vitara", "Suzuki", "Vitara",
                 2015, None, FuelType.PETROL, 47, 6.3),
    # -- Electric vehicles (WLTP × 0.80 = real range; kWh includes
    #    ~10 % charging loss vs wall-plug) ------------------------------
    VehicleModel("tesla_model_3_lr", "Tesla", "Model 3 Long Range",
                 2019, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=75, ev_range_km=480, consumption_kwh100km=16.5),
    VehicleModel("tesla_model_3_sr", "Tesla", "Model 3 RWD",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=60, ev_range_km=400, consumption_kwh100km=15.5),
    VehicleModel("tesla_model_y_lr", "Tesla", "Model Y Long Range",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=75, ev_range_km=440, consumption_kwh100km=17.5),
    VehicleModel("tesla_model_y_rwd", "Tesla", "Model Y RWD",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=60, ev_range_km=370, consumption_kwh100km=16.5),
    VehicleModel("vw_id3", "Volkswagen", "ID.3",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=58, ev_range_km=350, consumption_kwh100km=17.0),
    VehicleModel("vw_id4", "Volkswagen", "ID.4",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=430, consumption_kwh100km=18.5),
    VehicleModel("vw_id5", "Volkswagen", "ID.5",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=440, consumption_kwh100km=18.0),
    VehicleModel("vw_id7", "Volkswagen", "ID.7",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=500, consumption_kwh100km=16.5),
    VehicleModel("kia_ev6", "Kia", "EV6",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=420, consumption_kwh100km=17.5),
    VehicleModel("kia_niro_ev", "Kia", "Niro EV",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=64, ev_range_km=370, consumption_kwh100km=16.8),
    VehicleModel("hyundai_ioniq5", "Hyundai", "Ioniq 5",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=420, consumption_kwh100km=17.5),
    VehicleModel("hyundai_ioniq6", "Hyundai", "Ioniq 6",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=480, consumption_kwh100km=15.0),
    VehicleModel("hyundai_kona_ev", "Hyundai", "Kona Electric",
                 2018, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=64, ev_range_km=380, consumption_kwh100km=15.8),
    VehicleModel("bmw_ix", "BMW", "iX",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=105, ev_range_km=520, consumption_kwh100km=20.0),
    VehicleModel("bmw_i4", "BMW", "i4",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=80, ev_range_km=460, consumption_kwh100km=17.0),
    VehicleModel("bmw_ix1", "BMW", "iX1",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=64, ev_range_km=350, consumption_kwh100km=18.0),
    VehicleModel("mercedes_eqa", "Mercedes-Benz", "EQA",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=66, ev_range_km=350, consumption_kwh100km=18.5),
    VehicleModel("mercedes_eqe", "Mercedes-Benz", "EQE",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=90, ev_range_km=500, consumption_kwh100km=17.5),
    VehicleModel("audi_q4_etron", "Audi", "Q4 e-tron",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=420, consumption_kwh100km=18.5),
    VehicleModel("audi_etron_gt", "Audi", "e-tron GT",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=85, ev_range_km=440, consumption_kwh100km=19.0),
    VehicleModel("renault_zoe", "Renault", "Zoe",
                 2019, 2024, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=52, ev_range_km=310, consumption_kwh100km=17.5),
    VehicleModel("renault_megane_etech", "Renault", "Mégane E-Tech",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=60, ev_range_km=380, consumption_kwh100km=15.8),
    VehicleModel("renault_scenic_etech", "Renault", "Scénic E-Tech",
                 2024, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=87, ev_range_km=500, consumption_kwh100km=17.0),
    VehicleModel("peugeot_e208", "Peugeot", "e-208",
                 2019, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51, ev_range_km=320, consumption_kwh100km=16.0),
    VehicleModel("peugeot_e2008", "Peugeot", "e-2008",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51, ev_range_km=310, consumption_kwh100km=16.8),
    VehicleModel("citroen_ec4", "Citroën", "ë-C4",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51, ev_range_km=310, consumption_kwh100km=16.5),
    VehicleModel("opel_corsa_e", "Opel", "Corsa-e",
                 2019, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51, ev_range_km=320, consumption_kwh100km=15.8),
    VehicleModel("opel_mokka_e", "Opel", "Mokka-e",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51, ev_range_km=310, consumption_kwh100km=16.5),
    VehicleModel("fiat_500e", "Fiat", "500e",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=42, ev_range_km=270, consumption_kwh100km=14.5),
    VehicleModel("mg4", "MG", "MG4",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=64, ev_range_km=360, consumption_kwh100km=17.0),
    VehicleModel("skoda_enyaq", "Skoda", "Enyaq iV",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=420, consumption_kwh100km=18.0),
    VehicleModel("cupra_born", "CUPRA", "Born",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=77, ev_range_km=430, consumption_kwh100km=17.0),
    VehicleModel("volvo_ex30", "Volvo", "EX30",
                 2024, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=64, ev_range_km=390, consumption_kwh100km=17.5),
    VehicleModel("polestar_2", "Polestar", "2",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=78, ev_range_km=440, consumption_kwh100km=17.5),
    VehicleModel("dacia_spring", "Dacia", "Spring",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=27, ev_range_km=180, consumption_kwh100km=14.5),
    VehicleModel("nissan_leaf", "Nissan", "Leaf",
                 2018, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=39, ev_range_km=220, consumption_kwh100km=17.0),
    VehicleModel("nissan_ariya", "Nissan", "Ariya",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=87, ev_range_km=440, consumption_kwh100km=19.0),
    VehicleModel("byd_atto3", "BYD", "Atto 3",
                 2022, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=60, ev_range_km=330, consumption_kwh100km=17.5),
    VehicleModel("byd_dolphin", "BYD", "Dolphin",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=61, ev_range_km=350, consumption_kwh100km=16.0),
    VehicleModel("byd_seal", "BYD", "Seal",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=82, ev_range_km=460, consumption_kwh100km=17.5),

    # -- BMW -----------------------------------------------------------------
    VehicleModel("bmw_serie_5_g30", "BMW", "Serie 5 G30",
                 2017, None, FuelType.PETROL, 60, 8.0),
    VehicleModel("bmw_serie_5_g30_diesel", "BMW", "Serie 5 G30",
                 2017, None, FuelType.DIESEL, 60, 5.8),
    VehicleModel("bmw_x1_u11", "BMW", "X1 U11",
                 2022, None, FuelType.PETROL, 54, 7.2),
    VehicleModel("bmw_x1_u11_diesel", "BMW", "X1 U11",
                 2022, None, FuelType.DIESEL, 54, 5.5),
    VehicleModel("bmw_x3_g01", "BMW", "X3 G01",
                 2017, None, FuelType.PETROL, 65, 8.8),
    VehicleModel("bmw_x3_g01_diesel", "BMW", "X3 G01",
                 2017, None, FuelType.DIESEL, 65, 6.6),
    VehicleModel("bmw_x5_g05", "BMW", "X5 G05",
                 2018, None, FuelType.PETROL, 83, 10.5),
    VehicleModel("bmw_x5_g05_diesel", "BMW", "X5 G05",
                 2018, None, FuelType.DIESEL, 83, 7.5),

    # -- Mercedes-Benz -------------------------------------------------------
    VehicleModel("mercedes_c_w206", "Mercedes-Benz", "Clase C W206",
                 2021, None, FuelType.PETROL, 66, 7.8),
    VehicleModel("mercedes_c_w206_diesel", "Mercedes-Benz", "Clase C W206",
                 2021, None, FuelType.DIESEL, 66, 5.8),
    VehicleModel("mercedes_e_w213", "Mercedes-Benz", "Clase E W213",
                 2016, None, FuelType.PETROL, 66, 8.0),
    VehicleModel("mercedes_e_w213_diesel", "Mercedes-Benz", "Clase E W213",
                 2016, None, FuelType.DIESEL, 66, 5.8),
    VehicleModel("mercedes_glc_x254", "Mercedes-Benz", "GLC X254",
                 2022, None, FuelType.PETROL, 63, 8.5),
    VehicleModel("mercedes_glc_x254_diesel", "Mercedes-Benz", "GLC X254",
                 2022, None, FuelType.DIESEL, 63, 6.2),
    VehicleModel("mercedes_gle_v167", "Mercedes-Benz", "GLE V167",
                 2019, None, FuelType.PETROL, 85, 11.0),
    VehicleModel("mercedes_gle_v167_diesel", "Mercedes-Benz", "GLE V167",
                 2019, None, FuelType.DIESEL, 85, 7.8),
    VehicleModel("mercedes_eqc", "Mercedes-Benz", "EQC",
                 2019, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=80, ev_range_km=350, consumption_kwh100km=24.0),

    # -- Audi ----------------------------------------------------------------
    VehicleModel("audi_a4_b9", "Audi", "A4 B9",
                 2015, None, FuelType.PETROL, 58, 7.2),
    VehicleModel("audi_a4_b9_diesel", "Audi", "A4 B9",
                 2015, None, FuelType.DIESEL, 58, 5.5),
    VehicleModel("audi_a6_c8", "Audi", "A6 C8",
                 2018, None, FuelType.PETROL, 63, 8.5),
    VehicleModel("audi_a6_c8_diesel", "Audi", "A6 C8",
                 2018, None, FuelType.DIESEL, 63, 6.0),
    VehicleModel("audi_q7_4m", "Audi", "Q7 4M",
                 2015, None, FuelType.PETROL, 85, 10.8),
    VehicleModel("audi_q7_4m_diesel", "Audi", "Q7 4M",
                 2015, None, FuelType.DIESEL, 85, 7.8),
    VehicleModel("audi_etron_55", "Audi", "e-tron 55",
                 2018, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=95, ev_range_km=350, consumption_kwh100km=26.0),

    # -- Porsche -------------------------------------------------------------
    VehicleModel("porsche_cayenne_petrol", "Porsche", "Cayenne 9YA",
                 2018, None, FuelType.PETROL, 90, 11.5),
    VehicleModel("porsche_cayenne_diesel", "Porsche", "Cayenne 9Y0",
                 2010, 2018, FuelType.DIESEL, 80, 8.5),
    VehicleModel("porsche_macan_petrol", "Porsche", "Macan 95B",
                 2014, 2024, FuelType.PETROL, 75, 10.0),

    # -- Renault / Peugeot / Citroën / DS / Opel / Dacia extras --------------
    VehicleModel("renault_arkana_etech", "Renault", "Arkana E-Tech",
                 2021, None, FuelType.HYBRID, 40, 4.8),
    VehicleModel("renault_austral_etech", "Renault", "Austral E-Tech",
                 2022, None, FuelType.HYBRID, 55, 6.2),
    VehicleModel("peugeot_308_iii_diesel", "Peugeot", "308 III",
                 2021, None, FuelType.DIESEL, 52, 5.2),
    VehicleModel("peugeot_408", "Peugeot", "408",
                 2022, None, FuelType.PETROL, 54, 7.1),
    VehicleModel("peugeot_508_diesel", "Peugeot", "508",
                 2018, None, FuelType.DIESEL, 65, 5.7),
    VehicleModel("citroen_berlingo_iii", "Citroën", "Berlingo III",
                 2018, None, FuelType.PETROL, 50, 7.8),
    VehicleModel("citroen_c5_aircross_diesel", "Citroën", "C5 Aircross",
                 2018, None, FuelType.DIESEL, 52, 5.7),
    VehicleModel("ds3_crossback_etense", "DS Automobiles", "DS3 Crossback E-Tense",
                 2019, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=50.0, ev_range_km=255, consumption_kwh100km=19.5),
    VehicleModel("ds7_crossback_diesel", "DS Automobiles", "DS7 Crossback",
                 2017, None, FuelType.DIESEL, 60, 6.7),
    VehicleModel("opel_grandland_x_diesel", "Opel", "Grandland X",
                 2017, None, FuelType.DIESEL, 53, 6.0),
    VehicleModel("dacia_jogger", "Dacia", "Jogger",
                 2021, None, FuelType.PETROL, 50, 7.2),
    VehicleModel("dacia_jogger_lpg", "Dacia", "Jogger ECO-G",
                 2022, None, FuelType.LPG, 40, 9.2),

    # -- Fiat ----------------------------------------------------------------
    VehicleModel("fiat_500x", "Fiat", "500X",
                 2014, None, FuelType.PETROL, 45, 7.2),
    VehicleModel("fiat_tipo_petrol", "Fiat", "Tipo",
                 2015, None, FuelType.PETROL, 50, 6.8),
    VehicleModel("fiat_tipo_diesel", "Fiat", "Tipo",
                 2015, None, FuelType.DIESEL, 50, 5.2),
    VehicleModel("fiat_doblo_petrol", "Fiat", "Doblò",
                 2022, None, FuelType.PETROL, 50, 7.8),
    # fiat_500e already in list above

    # -- Alfa Romeo ----------------------------------------------------------
    VehicleModel("alfa_giulia_petrol", "Alfa Romeo", "Giulia",
                 2016, None, FuelType.PETROL, 58, 7.8),
    VehicleModel("alfa_giulia_diesel", "Alfa Romeo", "Giulia",
                 2016, None, FuelType.DIESEL, 58, 5.6),
    VehicleModel("alfa_stelvio_petrol", "Alfa Romeo", "Stelvio",
                 2017, None, FuelType.PETROL, 64, 8.5),
    VehicleModel("alfa_stelvio_diesel", "Alfa Romeo", "Stelvio",
                 2017, None, FuelType.DIESEL, 64, 6.2),
    VehicleModel("alfa_tonale_phev", "Alfa Romeo", "Tonale PHEV",
                 2022, None, FuelType.HYBRID, 36, 2.2),

    # -- Lancia --------------------------------------------------------------
    VehicleModel("lancia_ypsilon_iii", "Lancia", "Ypsilon III",
                 2011, 2024, FuelType.PETROL, 35, 6.4),

    # -- Jeep ----------------------------------------------------------------
    VehicleModel("jeep_compass_petrol", "Jeep", "Compass",
                 2017, None, FuelType.PETROL, 57, 7.8),
    VehicleModel("jeep_renegade_petrol", "Jeep", "Renegade",
                 2014, None, FuelType.PETROL, 48, 7.5),
    VehicleModel("jeep_avenger_ev", "Jeep", "Avenger",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=54.0, ev_range_km=340, consumption_kwh100km=15.9),

    # -- SEAT extras ---------------------------------------------------------
    VehicleModel("seat_tarraco_petrol", "SEAT", "Tarraco",
                 2018, None, FuelType.PETROL, 60, 8.2),
    VehicleModel("seat_tarraco_diesel", "SEAT", "Tarraco",
                 2018, None, FuelType.DIESEL, 60, 6.2),

    # -- CUPRA extras --------------------------------------------------------
    # cupra_born already in list above
    VehicleModel("cupra_ateca_petrol", "CUPRA", "Ateca",
                 2016, None, FuelType.PETROL, 55, 7.8),

    # -- Mini ----------------------------------------------------------------
    VehicleModel("mini_cooper_f56_petrol", "Mini", "Cooper F56",
                 2014, None, FuelType.PETROL, 44, 6.5),
    VehicleModel("mini_cooper_f56_diesel", "Mini", "Cooper F56",
                 2014, None, FuelType.DIESEL, 44, 4.8),
    VehicleModel("mini_countryman_f60_petrol", "Mini", "Countryman F60",
                 2017, None, FuelType.PETROL, 51, 7.4),
    VehicleModel("mini_electric_f56e", "Mini", "Cooper Electric F56e",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=32.6, ev_range_km=215, consumption_kwh100km=15.2),

    # -- Land Rover ----------------------------------------------------------
    VehicleModel("lr_defender_110_diesel", "Land Rover", "Defender 110",
                 2020, None, FuelType.DIESEL, 90, 9.8),
    VehicleModel("lr_discovery_sport_diesel", "Land Rover", "Discovery Sport",
                 2014, None, FuelType.DIESEL, 70, 7.2),

    # -- Jaguar --------------------------------------------------------------
    VehicleModel("jaguar_fpace_diesel", "Jaguar", "F-Pace",
                 2016, None, FuelType.DIESEL, 73, 7.0),
    VehicleModel("jaguar_ipace_ev", "Jaguar", "I-Pace",
                 2018, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=90.0, ev_range_km=380, consumption_kwh100km=23.7),

    # -- Volvo extras --------------------------------------------------------
    VehicleModel("volvo_xc40_petrol", "Volvo", "XC40",
                 2017, None, FuelType.PETROL, 54, 7.8),
    VehicleModel("volvo_xc40_diesel", "Volvo", "XC40",
                 2017, None, FuelType.DIESEL, 54, 5.8),
    VehicleModel("volvo_xc40_recharge", "Volvo", "XC40 Recharge",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=82.0, ev_range_km=420, consumption_kwh100km=19.5),
    VehicleModel("volvo_xc60_diesel", "Volvo", "XC60",
                 2017, None, FuelType.DIESEL, 71, 6.5),
    VehicleModel("volvo_xc90_diesel", "Volvo", "XC90",
                 2015, None, FuelType.DIESEL, 71, 8.0),

    # -- Toyota extras -------------------------------------------------------
    VehicleModel("toyota_rav4_v_hev", "Toyota", "RAV4 V Hybrid",
                 2019, None, FuelType.HYBRID, 55, 5.8),
    VehicleModel("toyota_land_cruiser_300_diesel", "Toyota", "Land Cruiser 300",
                 2021, None, FuelType.DIESEL, 110, 11.5),
    VehicleModel("toyota_camry_viii_hev", "Toyota", "Camry VIII Hybrid",
                 2019, None, FuelType.HYBRID, 60, 6.0),
    VehicleModel("toyota_prius_iv_hev", "Toyota", "Prius IV Hybrid",
                 2015, 2022, FuelType.HYBRID, 43, 4.5),

    # -- Skoda extras --------------------------------------------------------
    VehicleModel("skoda_octavia_iv_diesel", "Skoda", "Octavia IV",
                 2020, None, FuelType.DIESEL, 55, 5.3),
    VehicleModel("skoda_superb_iii_diesel", "Skoda", "Superb III",
                 2015, 2024, FuelType.DIESEL, 66, 5.8),
    VehicleModel("skoda_kamiq", "Skoda", "Kamiq",
                 2019, None, FuelType.PETROL, 50, 6.5),

    # -- Kia extras ----------------------------------------------------------
    VehicleModel("kia_ceed_iii_diesel", "Kia", "Ceed III",
                 2018, None, FuelType.DIESEL, 50, 5.0),
    VehicleModel("kia_sportage_v_hev", "Kia", "Sportage V Hybrid",
                 2021, None, FuelType.HYBRID, 52, 6.2),
    VehicleModel("kia_stinger_diesel", "Kia", "Stinger",
                 2017, 2023, FuelType.DIESEL, 60, 7.2),
    VehicleModel("kia_picanto_ja", "Kia", "Picanto JA",
                 2017, None, FuelType.PETROL, 35, 5.8),
    VehicleModel("kia_xceed", "Kia", "XCeed",
                 2019, None, FuelType.PETROL, 45, 6.8),

    # -- Hyundai extras ------------------------------------------------------
    VehicleModel("hyundai_i20_iii", "Hyundai", "i20 III",
                 2020, None, FuelType.PETROL, 40, 5.8),
    VehicleModel("hyundai_santa_fe_iv_diesel", "Hyundai", "Santa Fe IV",
                 2018, None, FuelType.DIESEL, 67, 7.5),
    VehicleModel("hyundai_bayon", "Hyundai", "Bayon",
                 2021, None, FuelType.PETROL, 40, 6.2),
    VehicleModel("hyundai_elantra_cn7", "Hyundai", "Elantra CN7",
                 2020, None, FuelType.PETROL, 53, 7.0),

    # -- Mazda extras --------------------------------------------------------
    VehicleModel("mazda_2_dj", "Mazda", "Mazda2 DJ",
                 2015, None, FuelType.PETROL, 44, 6.2),
    VehicleModel("mazda_cx30_dm", "Mazda", "CX-30",
                 2019, None, FuelType.PETROL, 51, 7.0),
    VehicleModel("mazda_cx60_phev", "Mazda", "CX-60 PHEV",
                 2022, None, FuelType.HYBRID, 50, 7.5,
                 battery_kwh=17.8, ev_range_km=45),
    VehicleModel("mazda_mx5_nd", "Mazda", "MX-5 ND",
                 2015, None, FuelType.PETROL, 45, 8.2),

    # -- Nissan extras -------------------------------------------------------
    VehicleModel("nissan_juke_f16", "Nissan", "Juke F16",
                 2019, None, FuelType.PETROL, 41, 6.8),
    VehicleModel("nissan_qashqai_j12_mhev", "Nissan", "Qashqai J12 mHEV",
                 2021, None, FuelType.PETROL, 55, 7.0),
    VehicleModel("nissan_micra_k14", "Nissan", "Micra K14",
                 2017, None, FuelType.PETROL, 41, 6.0),

    # -- Honda ---------------------------------------------------------------
    VehicleModel("honda_jazz_ge_hybrid", "Honda", "Jazz GE e:HEV",
                 2020, None, FuelType.HYBRID, 40, 4.8),
    VehicleModel("honda_crv_v_hybrid", "Honda", "CR-V V e:HEV",
                 2018, 2023, FuelType.HYBRID, 53, 6.5),
    VehicleModel("honda_zrv_hybrid", "Honda", "ZR-V e:HEV",
                 2023, None, FuelType.HYBRID, 53, 6.3),
    VehicleModel("honda_civic_xi", "Honda", "Civic XI",
                 2021, None, FuelType.PETROL, 46, 7.5),

    # -- Suzuki extras -------------------------------------------------------
    VehicleModel("suzuki_sx4_scross", "Suzuki", "SX4 S-Cross",
                 2021, None, FuelType.PETROL, 47, 6.5),
    VehicleModel("suzuki_swace_hybrid", "Suzuki", "Swace Hybrid",
                 2020, None, FuelType.HYBRID, 43, 4.8),

    # -- Mitsubishi ----------------------------------------------------------
    VehicleModel("mitsubishi_eclipse_cross_phev", "Mitsubishi", "Eclipse Cross PHEV",
                 2019, None, FuelType.HYBRID, 43, 8.0,
                 battery_kwh=13.8, ev_range_km=38),
    VehicleModel("mitsubishi_outlander_phev", "Mitsubishi", "Outlander PHEV",
                 2021, None, FuelType.HYBRID, 45, 8.0,
                 battery_kwh=20.0, ev_range_km=65),

    # -- Tesla extras --------------------------------------------------------
    VehicleModel("tesla_model_s_lr", "Tesla", "Model S Long Range",
                 2016, None, FuelType.ELECTRIC, 0, 0,
                 battery_kwh=100.0, ev_range_km=530, consumption_kwh100km=20.0),
    VehicleModel("tesla_model_x_lr", "Tesla", "Model X Long Range",
                 2016, None, FuelType.ELECTRIC, 0, 0,
                 battery_kwh=100.0, ev_range_km=490, consumption_kwh100km=22.0),

    # -- VW Vans -------------------------------------------------------------
    VehicleModel("vw_caddy_5_diesel", "Volkswagen", "Caddy 5",
                 2020, None, FuelType.DIESEL, 50, 5.8),
    VehicleModel("vw_transporter_t6_diesel", "Volkswagen", "Transporter T6",
                 2019, None, FuelType.DIESEL, 80, 8.5),

    # -- Ford Vans + EV ------------------------------------------------------
    VehicleModel("ford_transit_custom_diesel", "Ford", "Transit Custom",
                 2018, None, FuelType.DIESEL, 70, 8.0),
    VehicleModel("ford_tourneo_connect_diesel", "Ford", "Tourneo Connect",
                 2022, None, FuelType.DIESEL, 55, 5.5),
    VehicleModel("ford_mustang_mache", "Ford", "Mustang Mach-E",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=70.0, ev_range_km=320, consumption_kwh100km=19.5),

    # -- Mercedes Vans + EV --------------------------------------------------
    VehicleModel("mercedes_vito_diesel", "Mercedes-Benz", "Vito W447",
                 2014, None, FuelType.DIESEL, 75, 8.2),
    VehicleModel("mercedes_citan_diesel", "Mercedes-Benz", "Citan W420",
                 2021, None, FuelType.DIESEL, 55, 5.8),
    VehicleModel("mercedes_eqv", "Mercedes-Benz", "EQV 300",
                 2020, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=100.0, ev_range_km=340, consumption_kwh100km=26.0),

    # -- Stellantis Vans -----------------------------------------------------
    VehicleModel("peugeot_expert_diesel", "Peugeot", "Expert",
                 2016, None, FuelType.DIESEL, 72, 7.8),
    VehicleModel("fiat_scudo_diesel", "Fiat", "Scudo",
                 2022, None, FuelType.DIESEL, 72, 7.9),
    VehicleModel("citroen_jumpy_diesel", "Citroën", "Jumpy",
                 2016, None, FuelType.DIESEL, 72, 7.8),

    # -- BMW Serie 2 Active Tourer -------------------------------------------
    VehicleModel("bmw_serie_2_at", "BMW", "Serie 2 Active Tourer",
                 2021, None, FuelType.PETROL, 46, 7.2),
    VehicleModel("bmw_serie_2_at_diesel", "BMW", "Serie 2 Active Tourer",
                 2021, None, FuelType.DIESEL, 46, 5.5),

    # -- Mini Clubman --------------------------------------------------------
    VehicleModel("mini_clubman", "MINI", "Clubman F54",
                 2015, None, FuelType.PETROL, 44, 7.0),

    # -- Motos ---------------------------------------------------------------
    VehicleModel("moto_honda_cb125r", "Honda", "CB125R",
                 2018, None, FuelType.PETROL, 11, 3.0),
    VehicleModel("moto_honda_cb500f", "Honda", "CB500F",
                 2016, None, FuelType.PETROL, 17, 4.5),
    VehicleModel("moto_honda_africa_twin", "Honda", "Africa Twin",
                 2016, None, FuelType.PETROL, 18.8, 5.5),
    VehicleModel("moto_honda_cb1000r", "Honda", "CB1000R",
                 2018, None, FuelType.PETROL, 16, 6.0),
    VehicleModel("moto_yamaha_mt07", "Yamaha", "MT-07",
                 2014, None, FuelType.PETROL, 13, 5.0),
    VehicleModel("moto_yamaha_mt09", "Yamaha", "MT-09",
                 2014, None, FuelType.PETROL, 14, 5.5),
    VehicleModel("moto_yamaha_tracer9", "Yamaha", "Tracer 9",
                 2021, None, FuelType.PETROL, 18, 5.5),
    VehicleModel("moto_bmw_r1250gs", "BMW", "R1250GS",
                 2019, None, FuelType.PETROL, 20, 6.5),
    VehicleModel("moto_bmw_f900r", "BMW", "F900R",
                 2020, None, FuelType.PETROL, 13, 5.0),
    VehicleModel("moto_kawasaki_z900", "Kawasaki", "Z900",
                 2017, None, FuelType.PETROL, 17, 5.8),
    VehicleModel("moto_ducati_monster", "Ducati", "Monster",
                 2021, None, FuelType.PETROL, 14.5, 6.2),
    VehicleModel("moto_ktm_790duke", "KTM", "790 Duke",
                 2018, None, FuelType.PETROL, 14, 5.5),
    VehicleModel("moto_triumph_tiger900", "Triumph", "Tiger 900",
                 2020, None, FuelType.PETROL, 20, 6.0),

    # -- Motos adicionales ---------------------------------------------------
    VehicleModel("moto_harley_street_glide", "Harley-Davidson", "Street Glide",
                 2019, None, FuelType.PETROL, 22.7, 8.0),
    VehicleModel("moto_harley_sportster_s", "Harley-Davidson", "Sportster S",
                 2021, None, FuelType.PETROL, 11.8, 7.2),
    VehicleModel("moto_suzuki_gsxr750", "Suzuki", "GSX-R750",
                 2017, None, FuelType.PETROL, 17, 6.8),
    VehicleModel("moto_suzuki_vstrom1050", "Suzuki", "V-Strom 1050",
                 2020, None, FuelType.PETROL, 20, 6.5),
    VehicleModel("moto_suzuki_vstrom650", "Suzuki", "V-Strom 650",
                 2017, None, FuelType.PETROL, 20, 5.8),
    VehicleModel("moto_honda_nt1100", "Honda", "NT1100",
                 2022, None, FuelType.PETROL, 21.1, 5.5),
    VehicleModel("moto_honda_xadv", "Honda", "X-ADV",
                 2017, None, FuelType.PETROL, 13.2, 5.0),
    VehicleModel("moto_honda_goldwing", "Honda", "Gold Wing",
                 2018, None, FuelType.PETROL, 21.1, 7.5),
    VehicleModel("moto_royalenfield_himalayan", "Royal Enfield", "Himalayan",
                 2021, None, FuelType.PETROL, 15, 4.5),
    VehicleModel("moto_royalenfield_continental", "Royal Enfield", "Continental GT 650",
                 2019, None, FuelType.PETROL, 12.5, 5.5),
    VehicleModel("moto_yamaha_nmax125", "Yamaha", "NMAX 125",
                 2021, None, FuelType.PETROL, 7.1, 3.2),
    VehicleModel("moto_yamaha_xmax300", "Yamaha", "XMAX 300",
                 2017, None, FuelType.PETROL, 13.2, 4.5),
    VehicleModel("moto_bmw_gs1250adventure", "BMW", "R1250GS Adventure",
                 2019, None, FuelType.PETROL, 30, 6.2),
    VehicleModel("moto_bmw_s1000rr", "BMW", "S1000RR",
                 2019, None, FuelType.PETROL, 16.5, 7.5),
    VehicleModel("moto_kawasaki_ninja650", "Kawasaki", "Ninja 650",
                 2017, None, FuelType.PETROL, 15, 5.5),
    VehicleModel("moto_kawasaki_versys1000", "Kawasaki", "Versys 1000",
                 2019, None, FuelType.PETROL, 21, 6.5),
    VehicleModel("moto_ktm_890adventure", "KTM", "890 Adventure",
                 2021, None, FuelType.PETROL, 20, 6.0),
    VehicleModel("moto_triumph_scrambler1200", "Triumph", "Scrambler 1200",
                 2019, None, FuelType.PETROL, 16, 6.5),
    VehicleModel("moto_triumph_speedtriple1200", "Triumph", "Speed Triple 1200",
                 2021, None, FuelType.PETROL, 15.5, 7.0),
    VehicleModel("moto_vespa_gts300", "Vespa", "GTS 300",
                 2017, None, FuelType.PETROL, 9, 4.8),

    # -- Autocaravanas / Campers ---------------------------------------------
    VehicleModel("caravan_fiat_ducato_panel", "Furgoneta / Camper", "Fiat Ducato Panel Van",
                 2014, None, FuelType.DIESEL, 90, 10.5),
    VehicleModel("caravan_class_b", "Autocaravana", "Camper Compacta (Clase B)",
                 2015, None, FuelType.DIESEL, 70, 12.0),
    VehicleModel("caravan_class_c", "Autocaravana", "Autocaravana Alcoba (Clase C)",
                 2015, None, FuelType.DIESEL, 90, 15.0),
    VehicleModel("caravan_class_a_large", "Autocaravana", "Autocaravana Integral (Clase A)",
                 2015, None, FuelType.DIESEL, 100, 20.0),
    VehicleModel("caravan_vw_california", "Furgoneta / Camper", "Volkswagen California",
                 2015, None, FuelType.DIESEL, 80, 9.5),
    VehicleModel("caravan_mercedes_marco_polo", "Furgoneta / Camper", "Mercedes Marco Polo",
                 2014, None, FuelType.DIESEL, 70, 10.0),
    VehicleModel("caravan_ford_transit_camper", "Furgoneta / Camper", "Ford Transit Custom (camperizada)",
                 2016, None, FuelType.DIESEL, 70, 10.0),
    VehicleModel("caravan_hymer_b_ml_i", "Autocaravana", "Hymer B-ML i",
                 2019, None, FuelType.DIESEL, 100, 14.0),
    VehicleModel("caravan_sunlight_t65", "Autocaravana", "Sunlight T65",
                 2020, None, FuelType.DIESEL, 100, 13.5),
    VehicleModel("caravan_adria_coral", "Autocaravana", "Adria Coral",
                 2018, None, FuelType.DIESEL, 90, 13.0),
    VehicleModel("caravan_eriba_touring", "Caravana remolque", "Eriba Touring (remolque)",
                 2015, None, FuelType.DIESEL, 0, 0.0),  # remolque — consumo lo da el vehículo tractor

    # -- VW prestige / large -------------------------------------------------
    VehicleModel("vw_touareg_cr_diesel", "Volkswagen", "Touareg (CR)",
                 2018, None, FuelType.DIESEL, 75, 8.5),
    VehicleModel("vw_sharan_7n_diesel", "Volkswagen", "Sharan 7N",
                 2010, 2022, FuelType.DIESEL, 70, 7.2),
    VehicleModel("vw_arteon", "Volkswagen", "Arteon",
                 2017, None, FuelType.PETROL, 55, 8.0),

    # -- BMW large / prestige ------------------------------------------------
    VehicleModel("bmw_serie7_g11_diesel", "BMW", "Serie 7 (G11/G12)",
                 2019, None, FuelType.DIESEL, 78, 8.5),
    VehicleModel("bmw_x7_g07_diesel", "BMW", "X7 (G07)",
                 2019, None, FuelType.DIESEL, 83, 10.5),

    # -- Mercedes large / prestige -------------------------------------------
    VehicleModel("mercedes_s_w223_diesel", "Mercedes-Benz", "Clase S (W223)",
                 2020, None, FuelType.DIESEL, 75, 9.0),
    VehicleModel("mercedes_gls_x167_diesel", "Mercedes-Benz", "GLS (X167)",
                 2019, None, FuelType.DIESEL, 80, 11.0),
    VehicleModel("mercedes_sprinter_vs30_diesel", "Mercedes-Benz", "Sprinter (VS30)",
                 2018, None, FuelType.DIESEL, 75, 11.5),

    # -- Audi prestige -------------------------------------------------------
    VehicleModel("audi_a1_gb", "Audi", "A1 (GB)",
                 2018, None, FuelType.PETROL, 40, 6.5),
    VehicleModel("audi_a8_d5_diesel", "Audi", "A8 (D5)",
                 2017, None, FuelType.DIESEL, 73, 8.5),
    VehicleModel("audi_q8_4m_diesel", "Audi", "Q8 (4M)",
                 2018, None, FuelType.DIESEL, 73, 9.0),
    VehicleModel("audi_rs3_8y", "Audi", "RS3 (8Y)",
                 2021, None, FuelType.PETROL, 55, 10.5),

    # -- Commercial / other --------------------------------------------------
    VehicleModel("peugeot_partner_diesel", "Peugeot", "Partner",
                 2018, None, FuelType.DIESEL, 50, 7.5),
    VehicleModel("skoda_scala", "Skoda", "Scala",
                 2019, None, FuelType.PETROL, 50, 6.5),
    VehicleModel("skoda_kamiq_diesel", "Skoda", "Kamiq",
                 2019, None, FuelType.DIESEL, 40, 5.5),

    # -- Chinese EVs ---------------------------------------------------------
    VehicleModel("mg_zs_ev", "MG", "ZS EV",
                 2021, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=51.0, ev_range_km=300, consumption_kwh100km=17.0),
    VehicleModel("ora_funky_cat", "Ora", "Funky Cat",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=48.0, ev_range_km=280, consumption_kwh100km=17.0),
    VehicleModel("xpeng_g6", "Xpeng", "G6",
                 2023, None, FuelType.ELECTRIC, 0, 0.0,
                 battery_kwh=87.0, ev_range_km=500, consumption_kwh100km=16.0),
)


_BY_ID: dict[str, VehicleModel] = {v.id: v for v in VEHICLE_MODELS}


def all_models() -> tuple[VehicleModel, ...]:
    return VEHICLE_MODELS


def find(model_id: str) -> VehicleModel | None:
    return _BY_ID.get(model_id)
