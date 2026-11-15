// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_channels.js
//
// Source lists used by the channel grouping. The GA4 default channel group uses
// google's "source categories" list (SOURCE_CATEGORY_SEARCH, _SOCIAL...). The full list
// has ~800 entries, here we keep the ones that matter + a lot of brazilian sites that
// google simply ignores (buscape, zoom, meliuz, kwai...). Add yours at the bottom.
//
// Everything here is compared in lower case, after normalize_source().

module.exports = {
  search: [
    "google", "bing", "yahoo", "baidu", "duckduckgo", "yandex", "ecosia", "naver", "ask",
    "aol", "msn", "brave", "search.brave.com", "startpage", "startpage.com", "qwant", "qwant.com",
    "seznam", "sogou", "so.com", "daum", "coccoc", "search.yahoo.com", "br.search.yahoo.com",
    "yahoo.com", "bing.com", "cn.bing.com", "duckduckgo.com", "ecosia.org", "yandex.ru", "yandex.com",
    "search.aol.com", "presearch", "mojeek", "lens.google.com", "images.google.com", "m.baidu.com",
    "naver.com", "search.lilo.org", "kagi", "kagi.com", "you.com"
  ],

  social: [
    "facebook", "instagram", "threads", "threads.net", "twitter", "x.com", "t.co",
    "linkedin", "pinterest", "reddit", "old.reddit.com", "tiktok", "snapchat", "snapchat.com",
    "tumblr", "tumblr.com", "quora", "quora.com", "vk.com", "ok.ru", "kwai", "kwai.com",
    "discord", "discord.com", "telegram", "t.me", "web.telegram.org", "messenger", "messenger.com",
    "whatsapp", "line", "weibo", "wechat", "bsky.app", "bluesky", "mastodon.social", "skoob",
    "medium.com", "substack", "substack.com", "taringa", "badoo", "meetup.com"
  ],

  video: [
    "youtube", "youtu.be", "music.youtube.com", "vimeo", "vimeo.com", "twitch", "twitch.tv",
    "dailymotion", "dailymotion.com", "netflix", "netflix.com", "globoplay", "globoplay.globo.com",
    "primevideo", "primevideo.com", "wistia", "ted.com", "rumble.com", "kick.com"
  ],

  shopping: [
    "google shopping", "shopping.google.com", "shopping", "mercadolivre", "mercadolibre",
    "amazon", "shopee", "magalu", "americanas", "submarino", "casasbahia", "pontofrio",
    "extra.com.br", "aliexpress", "temu", "shein", "ebay", "etsy", "walmart", "buscape",
    "zoom.com.br", "olx", "kabum", "netshoes", "dafiti", "carrefour", "centauro", "leroymerlin",
    "madeiramadeira", "zattini", "enjoei", "elo7", "shoptime", "fastshop", "girafa", "tiktok shop"
  ],

  // marketplaces get their own channel in the custom grouping (subset of shopping)
  marketplaces: [
    "mercadolivre", "mercadolibre", "amazon", "shopee", "magalu", "americanas", "casasbahia",
    "aliexpress", "temu", "shein", "olx", "submarino", "carrefour", "netshoes", "dafiti",
    "madeiramadeira", "enjoei", "elo7", "tiktok shop"
  ],

  // the new kids. GA4 still throws these into "Referral" (nov/2026)
  ai_assistants: [
    "chatgpt", "chatgpt.com", "chat.openai.com", "openai", "openai.com", "perplexity",
    "perplexity.ai", "gemini", "gemini.google.com", "bard.google.com", "copilot",
    "copilot.microsoft.com", "copilot.cloud.microsoft", "edgeservices.bing.com", "claude",
    "claude.ai", "poe.com", "meta.ai", "deepseek", "chat.deepseek.com", "deepseek.com",
    "grok", "grok.com", "chat.mistral.ai", "mistral", "phind.com", "duck.ai",
    "notebooklm.google.com", "aistudio.google.com", "chat.qwen.ai", "manus.im"
  ],

  // these break attribution: user goes to pay and comes back as "pagseguro / referral".
  // configure them in GA4 (unwanted referrals) too, but old data still needs the fix.
  payment_gateways: [
    "pagseguro", "pagseguro.uol.com.br", "pagseguro.com.br", "sandbox.pagseguro.uol.com.br",
    "pagbank.com.br", "pagbank", "mercadopago", "mercadopago.com.br", "mercadopago.com",
    "paypal", "paypal.com", "picpay", "picpay.com", "cielo.com.br", "getnet.com.br",
    "pagar.me", "api.pagar.me", "stone.com.br", "ebanx.com", "adyen.com", "stripe.com",
    "checkout.stripe.com", "hooks.stripe.com", "iugu.com", "faturas.iugu.com", "asaas.com",
    "vindi.com.br", "moip.com.br", "wirecard.com.br", "appmax.com.br", "paghiper.com",
    "gerencianet.com.br", "efipay.com.br", "sejaefi.com.br", "juno.com.br", "yapay.com.br",
    "intermediador.yapay.com.br", "userede.com.br", "rede.com.br", "pagali.com.br",
    "pay.hotmart.com", "eduzz.com", "kiwify.com.br", "monetizze.com.br"
  ],
  // 3DS / bank authentication pages also show up as referral
  payment_gateway_patterns: [
    "cardinalcommerce", "arcot\\.com", "3dsecure", "securecode", "verifiedbyvisa",
    "acs[0-9]*\\.", "authentication\\.", "secure\\.bradesco", "itau\\.com\\.br", "bb\\.com\\.br",
    "nubank\\.com\\.br", "santander\\.com\\.br", "caixa\\.gov\\.br", "inter\\.co"
  ],

  // cashback / coupon sites. they love to take the last click right at checkout.
  // promo_coupon_hijacking looks at exactly that.
  cashback_coupons: [
    "meliuz", "meliuz.com.br", "cuponomia", "cuponomia.com.br", "cuponeria", "cuponeria.com.br",
    "picodi", "picodi.com", "cupomvalido", "cupomvalido.com.br", "pelando", "pelando.com.br",
    "promobit", "promobit.com.br", "gatry", "gatry.com", "hardmob", "hardmob.com.br",
    "beblue", "beblue.com.br", "cupons.com.br", "cuponation", "cuponation.com.br",
    "cashbackgo", "inter shop", "ame digital", "dotz", "dotz.com.br", "livelo", "livelo.com.br"
  ],

  whatsapp: ["whatsapp", "whatsapp.com", "web.whatsapp.com", "wa.me", "api.whatsapp.com", "wpp", "zap"],

  email_sources: ["email", "e-mail", "e_mail", "e mail", "newsletter"],

  // mediums used by the brazilian marketing teams I worked with. the custom grouping uses them
  custom_mediums: {
    affiliates: ["affiliate", "affiliates", "afiliado", "afiliados", "parceiro", "parceria"],
    influencers: ["influencer", "influencers", "influenciador", "influenciadores", "creator", "creators", "ugc", "publi"],
    cashback: ["cashback", "cupom", "cupons", "coupon", "coupons"],
    whatsapp: ["whatsapp", "wpp", "zap", "whats"],
    crm: ["crm", "newsletter", "email_mkt", "emailmkt", "automacao", "automation", "regua"]
  },

  // source normalization: canonical name -> variants. GA4 gives us "l.facebook.com",
  // "m.facebook.com", "facebook.com", "fb"... and the dashboard shows 5 lines for facebook.
  source_aliases: [
    { canonical: "facebook", values: ["facebook.com", "m.facebook.com", "l.facebook.com", "lm.facebook.com", "web.facebook.com", "business.facebook.com", "mbasic.facebook.com", "fb", "fb.com", "fb.me", "meta", "facebook ads", "fb_ads", "facebookads"] },
    { canonical: "instagram", values: ["instagram.com", "l.instagram.com", "ig", "insta", "instagram ads", "instagram_ads"] },
    { canonical: "google", values: ["google.com", "www.google.com", "googlesearch", "google ads", "googleads", "adwords", "com.google.android.googlequicksearchbox", "android-app://com.google.android.googlequicksearchbox"], pattern: "^(www\\.)?google\\.[a-z]{2,3}(\\.[a-z]{2})?$" },
    { canonical: "bing", values: ["bing.com", "www.bing.com", "cn.bing.com", "microsoft ads", "microsoftads"] },
    { canonical: "yahoo", values: ["yahoo.com", "search.yahoo.com", "br.search.yahoo.com", "br.yahoo.com"] },
    { canonical: "youtube", values: ["youtube.com", "m.youtube.com", "www.youtube.com", "youtu.be"] },
    { canonical: "linkedin", values: ["linkedin.com", "www.linkedin.com", "lnkd.in", "com.linkedin.android"] },
    { canonical: "twitter", values: ["twitter.com", "t.co", "mobile.twitter.com"] },
    { canonical: "pinterest", values: ["pinterest.com", "br.pinterest.com", "pin.it"] },
    { canonical: "reddit", values: ["reddit.com", "www.reddit.com", "out.reddit.com"] },
    { canonical: "tiktok", values: ["tiktok.com", "www.tiktok.com", "vm.tiktok.com", "tiktok ads"] },
    { canonical: "whatsapp", values: ["web.whatsapp.com", "api.whatsapp.com", "wa.me", "whatsapp.com", "wpp", "zap"] },
    { canonical: "gmail", values: ["mail.google.com", "com.google.android.gm", "android-app://com.google.android.gm"] },
    { canonical: "outlook", values: ["outlook.live.com", "outlook.office.com", "outlook.office365.com"] },
    { canonical: "chatgpt", values: ["chatgpt.com", "chat.openai.com", "openai", "openai.com"] },
    { canonical: "perplexity", values: ["perplexity.ai", "www.perplexity.ai"] },
    { canonical: "gemini", values: ["gemini.google.com", "bard.google.com"] },
    { canonical: "copilot", values: ["copilot.microsoft.com", "copilot.cloud.microsoft", "edgeservices.bing.com"] },
    { canonical: "claude", values: ["claude.ai"] },
    { canonical: "deepseek", values: ["chat.deepseek.com", "deepseek.com"] },
    { canonical: "mercadolivre", values: ["mercadolivre.com.br", "www.mercadolivre.com.br", "produto.mercadolivre.com.br", "mercadolibre.com"] },
    { canonical: "amazon", values: ["amazon.com.br", "www.amazon.com.br", "amazon.com"] },
    { canonical: "shopee", values: ["shopee.com.br"] },
    { canonical: "magalu", values: ["magazineluiza.com.br", "www.magazineluiza.com.br", "magazineluiza", "magazine luiza"] },
    { canonical: "americanas", values: ["americanas.com.br", "www.americanas.com.br"] },
    { canonical: "casasbahia", values: ["casasbahia.com.br", "www.casasbahia.com.br"] },
    { canonical: "kabum", values: ["kabum.com.br", "www.kabum.com.br"] },
    { canonical: "olx", values: ["olx.com.br", "www.olx.com.br"] },
    { canonical: "kwai", values: ["kwai.com", "www.kwai.com", "kwai-video.com"] }
  ]
};
