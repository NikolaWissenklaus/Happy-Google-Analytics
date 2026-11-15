// author: Francisco Lucas / Nikola Wissenklaus / Chico

// seeds_br.js
//
// Brazilian reference data. Population is from IBGE Censo 2022 (total 203.080.756).
// ga4_region is how GA4 usually writes the state name (no accents, sometimes "State of ...").
// br_uf_from_region() handles the variations, this list is the "official" one.

module.exports = {
  states: [
    { uf: "AC", state_name: "Acre", ga4_region: "Acre", macro_region: "Norte", capital: "Rio Branco", ibge_code: 12, population_2022: 830018 },
    { uf: "AL", state_name: "Alagoas", ga4_region: "Alagoas", macro_region: "Nordeste", capital: "Maceió", ibge_code: 27, population_2022: 3127683 },
    { uf: "AP", state_name: "Amapá", ga4_region: "Amapa", macro_region: "Norte", capital: "Macapá", ibge_code: 16, population_2022: 733759 },
    { uf: "AM", state_name: "Amazonas", ga4_region: "Amazonas", macro_region: "Norte", capital: "Manaus", ibge_code: 13, population_2022: 3941613 },
    { uf: "BA", state_name: "Bahia", ga4_region: "Bahia", macro_region: "Nordeste", capital: "Salvador", ibge_code: 29, population_2022: 14141626 },
    { uf: "CE", state_name: "Ceará", ga4_region: "Ceara", macro_region: "Nordeste", capital: "Fortaleza", ibge_code: 23, population_2022: 8794957 },
    { uf: "DF", state_name: "Distrito Federal", ga4_region: "Federal District", macro_region: "Centro-Oeste", capital: "Brasília", ibge_code: 53, population_2022: 2817381 },
    { uf: "ES", state_name: "Espírito Santo", ga4_region: "Espirito Santo", macro_region: "Sudeste", capital: "Vitória", ibge_code: 32, population_2022: 3833712 },
    { uf: "GO", state_name: "Goiás", ga4_region: "Goias", macro_region: "Centro-Oeste", capital: "Goiânia", ibge_code: 52, population_2022: 7056495 },
    { uf: "MA", state_name: "Maranhão", ga4_region: "Maranhao", macro_region: "Nordeste", capital: "São Luís", ibge_code: 21, population_2022: 6776699 },
    { uf: "MT", state_name: "Mato Grosso", ga4_region: "Mato Grosso", macro_region: "Centro-Oeste", capital: "Cuiabá", ibge_code: 51, population_2022: 3658649 },
    { uf: "MS", state_name: "Mato Grosso do Sul", ga4_region: "Mato Grosso do Sul", macro_region: "Centro-Oeste", capital: "Campo Grande", ibge_code: 50, population_2022: 2757013 },
    { uf: "MG", state_name: "Minas Gerais", ga4_region: "Minas Gerais", macro_region: "Sudeste", capital: "Belo Horizonte", ibge_code: 31, population_2022: 20539989 },
    { uf: "PA", state_name: "Pará", ga4_region: "Para", macro_region: "Norte", capital: "Belém", ibge_code: 15, population_2022: 8120131 },
    { uf: "PB", state_name: "Paraíba", ga4_region: "Paraiba", macro_region: "Nordeste", capital: "João Pessoa", ibge_code: 25, population_2022: 3974687 },
    { uf: "PR", state_name: "Paraná", ga4_region: "Parana", macro_region: "Sul", capital: "Curitiba", ibge_code: 41, population_2022: 11444380 },
    { uf: "PE", state_name: "Pernambuco", ga4_region: "Pernambuco", macro_region: "Nordeste", capital: "Recife", ibge_code: 26, population_2022: 9058931 },
    { uf: "PI", state_name: "Piauí", ga4_region: "Piaui", macro_region: "Nordeste", capital: "Teresina", ibge_code: 22, population_2022: 3271199 },
    { uf: "RJ", state_name: "Rio de Janeiro", ga4_region: "Rio de Janeiro", macro_region: "Sudeste", capital: "Rio de Janeiro", ibge_code: 33, population_2022: 16055174 },
    { uf: "RN", state_name: "Rio Grande do Norte", ga4_region: "Rio Grande do Norte", macro_region: "Nordeste", capital: "Natal", ibge_code: 24, population_2022: 3302729 },
    { uf: "RS", state_name: "Rio Grande do Sul", ga4_region: "Rio Grande do Sul", macro_region: "Sul", capital: "Porto Alegre", ibge_code: 43, population_2022: 10882965 },
    { uf: "RO", state_name: "Rondônia", ga4_region: "Rondonia", macro_region: "Norte", capital: "Porto Velho", ibge_code: 11, population_2022: 1581196 },
    { uf: "RR", state_name: "Roraima", ga4_region: "Roraima", macro_region: "Norte", capital: "Boa Vista", ibge_code: 14, population_2022: 636707 },
    { uf: "SC", state_name: "Santa Catarina", ga4_region: "Santa Catarina", macro_region: "Sul", capital: "Florianópolis", ibge_code: 42, population_2022: 7610361 },
    { uf: "SP", state_name: "São Paulo", ga4_region: "Sao Paulo", macro_region: "Sudeste", capital: "São Paulo", ibge_code: 35, population_2022: 44411238 },
    { uf: "SE", state_name: "Sergipe", ga4_region: "Sergipe", macro_region: "Nordeste", capital: "Aracaju", ibge_code: 28, population_2022: 2210004 },
    { uf: "TO", state_name: "Tocantins", ga4_region: "Tocantins", macro_region: "Norte", capital: "Palmas", ibge_code: 17, population_2022: 1511460 }
  ],

  // stopwords for site search mining. already without accents (we compare after remove_accents)
  stopwords_pt: [
    "a", "o", "e", "as", "os", "um", "uma", "uns", "umas", "de", "da", "do", "das", "dos", "em", "na", "no",
    "nas", "nos", "por", "para", "pra", "pro", "com", "sem", "sob", "sobre", "entre", "ate", "que", "qual",
    "quais", "se", "ou", "mas", "mais", "menos", "muito", "pouco", "ao", "aos", "pela", "pelo", "pelas",
    "pelos", "num", "numa", "esse", "essa", "este", "esta", "isso", "isto", "aquele", "aquela", "meu",
    "minha", "seu", "sua", "nosso", "nossa", "eu", "voce", "ele", "ela", "nos", "eles", "elas", "ja",
    "nao", "sim", "tem", "ter", "ser", "e", "foi", "sao", "como", "quando", "onde", "porque", "tipo",
    "the", "and", "of", "for", "with"
  ]
};
