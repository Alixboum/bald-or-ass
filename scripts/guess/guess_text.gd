class_name GuessText
extends RefCounted
## Interface strings for the fragment-guess mechanic. English is the base
## language; French is the alternative. Theme texts live in each theme file.

const LOCALES := ["en", "fr"]
const DEFAULT_LOCALE := "en"

static var locale := DEFAULT_LOCALE

const STRINGS := {
	"en": {
		"play": "Play",
		"editor": "Editor mode",
		"best": "Best score: %d",
		"image_count": "%d images in this theme",
		"missing": "Theme under construction: no images yet for “%s”.",
		"round": "Image %d / %d",
		"score": "Score %d",
		"keys": "Keys: %s · Enter = next",
		"correct": "Nice one!",
		"wrong": "Nope… it was “%s”.",
		"next": "Next image",
		"see_result": "See the result",
		"quit": "Quit game",
		"verdict": "Verdict",
		"perfect_theme": "Flawless. You never mix up a scalp and a backside.",
		"perfect": "Flawless!",
		"great": "Excellent eye.",
		"ok": "Not bad… but some fragments fooled you.",
		"bad": "Admit it: up close, everything looks the same.",
		"record": "New record!",
		"replay": "Play again",
		"home": "Home",
		"editor_title": "Editor mode",
		"editor_help": "Click and drag on the image to draw the area shown during the guess. Each drawing is saved automatically in this browser.",
		"previous": "◀ Previous",
		"following": "Next ▶",
		"preview": "Player preview (opaque mask)",
		"reset_zone": "Restore the theme's zone",
		"export_help": "To make your zones permanent, export the theme JSON and send it.",
		"copy": "Copy JSON",
		"download": "Download",
		"back": "Back",
		"no_images": "No images in this theme",
		"zone_custom": "Zone drawn in the editor",
		"zone_theme": "Zone from the theme file",
		"zone_saved": "Zone saved.",
		"zone_reset": "Original zone restored.",
		"copied": "Theme JSON copied to the clipboard (%d custom zones).",
		"downloaded": "File %s downloaded.",
		"language": "Language",
		"connect_wallet": "Connect wallet",
		"wallet": "Wallet %s",
		"no_wallet": "No wallet detected. Install a browser wallet (MetaMask, Rabby, Talisman…) to play on Hemi.",
		"onchain_on": "Each game starts with a transaction on Hemi mainnet.",
		"onchain_off": "Contract not deployed yet: games are not recorded on Hemi.",
		"tx_confirm": "Confirm the transaction in your wallet to start the game…",
		"tx_rejected": "Transaction cancelled. The game starts once the transaction is validated.",
		"tx_no_funds": "Not enough ETH on Hemi to pay the gas. Bridge a little ETH to Hemi, then try again.",
		"tx_wrong_chain": "Switch your wallet to the Hemi network, then try again.",
		"tx_pending": "A wallet request is already open. Check your wallet.",
		"tx_error": "Transaction failed: %s",
		"tx_recorded": "Game recorded on Hemi.",
		"my_games": "Your games on Hemi: %d",
		"leaderboard": "Leaderboard",
		"lb_subtitle": "Games played · Hemi mainnet",
		"lb_loading": "Reading the Hemi blockchain…",
		"lb_empty": "No games recorded yet. Be the first!",
		"lb_error": "Could not read the leaderboard (%s).",
		"lb_no_contract": "The leaderboard opens once the contract is deployed on Hemi.",
		"lb_totals": "%s · %s",
		"lb_players_one": "%d player",
		"lb_players": "%d players",
		"lb_games_one": "%d game",
		"lb_games": "%d games",
		"lb_you": "you",
		"refresh": "Refresh",
		"view_contract": "View contract",
		"deploy": "Deploy the contract on Hemi",
		"deploy_help": "No contract configured yet. Deploy GameCounter from your wallet (gas paid in ETH on Hemi).",
		"deploying": "Confirm the deployment in your wallet, then wait for the confirmation…",
		"deployed": "Contract deployed: %s. Send this address to make it permanent.",
		"deploy_failed": "Deployment failed (%s).",
	},
	"fr": {
		"play": "Jouer",
		"editor": "Mode éditeur",
		"best": "Meilleur score : %d",
		"image_count": "%d images dans ce thème",
		"missing": "Thème en construction : aucune image pour « %s » pour l'instant.",
		"round": "Image %d / %d",
		"score": "Score %d",
		"keys": "Clavier : %s · Entrée = suivante",
		"correct": "Bien vu !",
		"wrong": "Raté… c'était « %s ».",
		"next": "Image suivante",
		"see_result": "Voir le résultat",
		"quit": "Quitter la partie",
		"verdict": "Verdict",
		"perfect_theme": "Sans faute. Vous ne confondez jamais un crâne et un derrière.",
		"perfect": "Sans faute !",
		"great": "Excellent coup d'œil.",
		"ok": "Pas mal… mais certains fragments vous ont bien eu.",
		"bad": "Avouez-le : tout se ressemble de près.",
		"record": "Nouveau record !",
		"replay": "Rejouer",
		"home": "Accueil",
		"editor_title": "Mode éditeur",
		"editor_help": "Cliquez-glissez sur l'image pour tracer la zone visible pendant la devinette. Chaque tracé est enregistré automatiquement dans ce navigateur.",
		"previous": "◀ Précédente",
		"following": "Suivante ▶",
		"preview": "Aperçu joueur (masque opaque)",
		"reset_zone": "Revenir à la zone du thème",
		"export_help": "Pour rendre vos zones définitives, exportez le JSON du thème et transmettez-le.",
		"copy": "Copier le JSON",
		"download": "Télécharger",
		"back": "Retour",
		"no_images": "Aucune image dans ce thème",
		"zone_custom": "Zone tracée dans l'éditeur",
		"zone_theme": "Zone du fichier de thème",
		"zone_saved": "Zone enregistrée.",
		"zone_reset": "Zone d'origine rétablie.",
		"copied": "JSON du thème copié dans le presse-papiers (%d zones personnalisées).",
		"downloaded": "Fichier %s téléchargé.",
		"language": "Langue",
		"connect_wallet": "Connecter le wallet",
		"wallet": "Wallet %s",
		"no_wallet": "Aucun wallet détecté. Installez un wallet de navigateur (MetaMask, Rabby, Talisman…) pour jouer sur Hemi.",
		"onchain_on": "Chaque partie commence par une transaction sur Hemi mainnet.",
		"onchain_off": "Contrat pas encore déployé : les parties ne sont pas enregistrées sur Hemi.",
		"tx_confirm": "Validez la transaction dans votre wallet pour lancer la partie…",
		"tx_rejected": "Transaction annulée. La partie démarre une fois la transaction validée.",
		"tx_no_funds": "Pas assez d'ETH sur Hemi pour payer le gas. Transférez un peu d'ETH sur Hemi, puis réessayez.",
		"tx_wrong_chain": "Passez votre wallet sur le réseau Hemi, puis réessayez.",
		"tx_pending": "Une demande est déjà ouverte dans votre wallet. Vérifiez-le.",
		"tx_error": "Échec de la transaction : %s",
		"tx_recorded": "Partie enregistrée sur Hemi.",
		"my_games": "Vos parties sur Hemi : %d",
		"leaderboard": "Classement",
		"lb_subtitle": "Parties jouées · Hemi mainnet",
		"lb_loading": "Lecture de la blockchain Hemi…",
		"lb_empty": "Aucune partie enregistrée pour l'instant. Soyez le premier !",
		"lb_error": "Impossible de lire le classement (%s).",
		"lb_no_contract": "Le classement s'ouvrira une fois le contrat déployé sur Hemi.",
		"lb_totals": "%s · %s",
		"lb_players_one": "%d joueur",
		"lb_players": "%d joueurs",
		"lb_games_one": "%d partie",
		"lb_games": "%d parties",
		"lb_you": "vous",
		"refresh": "Actualiser",
		"view_contract": "Voir le contrat",
		"deploy": "Déployer le contrat sur Hemi",
		"deploy_help": "Aucun contrat configuré. Déployez GameCounter depuis votre wallet (gas payé en ETH sur Hemi).",
		"deploying": "Validez le déploiement dans votre wallet, puis patientez jusqu'à la confirmation…",
		"deployed": "Contrat déployé : %s. Transmettez cette adresse pour la rendre définitive.",
		"deploy_failed": "Échec du déploiement (%s).",
	},
}


static func set_locale(value: String) -> void:
	locale = value if value in LOCALES else DEFAULT_LOCALE


## Translated interface string, optionally formatted with arguments.
static func t(key: String, args: Variant = null) -> String:
	var table: Dictionary = STRINGS.get(locale, STRINGS[DEFAULT_LOCALE])
	var text := str(table.get(key, STRINGS[DEFAULT_LOCALE].get(key, key)))
	if args == null:
		return text
	return text % args


## Picks the current language from a theme value: either a plain string or
## {"en": "...", "fr": "..."}. Falls back to English, then any value.
static func pick(value: Variant) -> String:
	if value is Dictionary:
		if value.has(locale):
			return str(value[locale])
		if value.has(DEFAULT_LOCALE):
			return str(value[DEFAULT_LOCALE])
		return str(value.values()[0]) if not value.is_empty() else ""
	return str(value)
