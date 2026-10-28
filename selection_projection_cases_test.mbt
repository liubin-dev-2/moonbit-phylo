///|
test "projection audit compacted plans trace original source edges" {
  let source_0 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let projected_0 = source_0.prune(source_0.taxa()).unwrap()
  check_projected_plan(
    source_0,
    projected_0,
    [],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x4030000000000000UL,
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let source_1 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let projected_1 = source_1.prune(source_1.taxa()).unwrap()
  check_projected_plan(
    source_1,
    projected_1,
    ["A", "C"],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x401c000000000000UL,
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let source_2 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;")
  let projected_2 = source_2.prune(source_2.taxa()).unwrap()
  check_projected_plan(
    source_2,
    projected_2,
    [],
    ["A", "B", "C", "D"],
    3U,
    ["A", "D", "C"],
    0x4040800000000000UL,
    [
      (
        "A",
        0x402e000000000000UL,
        [
          (["A", "B"], 0x4022000000000000UL.reinterpret_as_double()),
          (["A"], 0x4018000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "D",
        0x402a000000000000UL,
        [
          (["C", "D"], 0x401c000000000000UL.reinterpret_as_double()),
          (["D"], 0x4018000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "C",
        0x4014000000000000UL,
        [(["C"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
    ],
    [
      (
        "A",
        0x402e000000000000UL,
        [
          (["A", "B"], 0x4022000000000000UL.reinterpret_as_double()),
          (["A"], 0x4008000000000000UL.reinterpret_as_double()),
          (["A"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x3ff0000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "D",
        0x402a000000000000UL,
        [
          (["C", "D"], 0x401c000000000000UL.reinterpret_as_double()),
          (["D"], 0x4018000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "C",
        0x4014000000000000UL,
        [(["C"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let source_3 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let projected_3 = source_3.prune(source_3.taxa()).unwrap()
  check_projected_plan(
    source_3,
    projected_3,
    [
      "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
      "Gelasimus_tetragonon", "Gelasimus_vocans",
    ],
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    3U,
    ["Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4054519afb894dc7UL,
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
}

///|
test "projection audit saved projection uses its own reloaded edge IDs" {
  let source_0 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let projected_0 = source_0.prune(source_0.taxa()).unwrap()
  let loaded_0 = @phylo.PhyloTree::from_newick(projected_0.tree.to_newick()).unwrap()
  check_pd_greedy(
    loaded_0,
    [],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x4030000000000000UL,
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let source_1 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let projected_1 = source_1.prune(source_1.taxa()).unwrap()
  let loaded_1 = @phylo.PhyloTree::from_newick(projected_1.tree.to_newick()).unwrap()
  check_pd_greedy(
    loaded_1,
    ["A", "C"],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x401c000000000000UL,
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let source_2 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;")
  let projected_2 = source_2.prune(source_2.taxa()).unwrap()
  let loaded_2 = @phylo.PhyloTree::from_newick(projected_2.tree.to_newick()).unwrap()
  check_pd_greedy(
    loaded_2,
    [],
    ["A", "B", "C", "D"],
    3U,
    ["A", "D", "C"],
    0x4040800000000000UL,
    [
      (
        "A",
        0x402e000000000000UL,
        [
          (["A", "B"], 0x4022000000000000UL.reinterpret_as_double()),
          (["A"], 0x4018000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "D",
        0x402a000000000000UL,
        [
          (["C", "D"], 0x401c000000000000UL.reinterpret_as_double()),
          (["D"], 0x4018000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "C",
        0x4014000000000000UL,
        [(["C"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let source_3 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let projected_3 = source_3.prune(source_3.taxa()).unwrap()
  let loaded_3 = @phylo.PhyloTree::from_newick(projected_3.tree.to_newick()).unwrap()
  check_pd_greedy(
    loaded_3,
    [
      "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
      "Gelasimus_tetragonon", "Gelasimus_vocans",
    ],
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    3U,
    ["Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4054519afb894dc7UL,
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
}

///|
test "projection audit compression has the documented Double ranking boundary" {
  let source = read("(A:10000000000000000,(B:10000000000000000):1)R;")
  let projected = source.prune(source.taxa()).unwrap()
  let before = source.faith_pd_greedy([], ["A", "B"], 1U).unwrap()
  let after = projected.tree.faith_pd_greedy([], ["A", "B"], 1U).unwrap()
  assert_eq(before.added_taxa, ["B"])
  assert_eq(after.added_taxa, ["A"])
  assert_eq(before.gain, 10000000000000000.0)
  assert_eq(after.gain, before.gain)
  check_mapping(source, projected)
}
