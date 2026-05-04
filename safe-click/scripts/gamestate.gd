extends Node

const API_URL = "http://rev.theballmarcus.dk:3000"
#const API_URL = "http://localhost:3000"  

const API_KEY = "x-api-key: megetUkendtAPiK4YsomAldrigBLIRFUNDET"
var headers = ["Content-Type: application/json", API_KEY]

signal mails_fetched(success: bool, added_count: int)

var mails := []
var finished_mails : Array = []
var fetch_in_progress := false

# Request stuff
var http: HTTPRequest

# User stats
var user_score := 0

var boss_comments := {
  "bad": [
	"Hvad var det i dag?\nJeg har set nybegyndere gøre det bedre.\nKom ikke igen i morgen med den indstilling.",
	"Du fik simple opgaver til at sejle.\nJeg skal ikke holde dig i hånden hver vagt.\nFå styr på det, før du spilder mere af min tid.",
	"Helt uacceptabel indsats i dag.\nDu var langsom, ukoncentreret og sjusket.\nRet op på det nu, ellers har vi et problem.",
	"Jeg ved ikke, hvad du lavede hele dagen.\nIntet blev gjort ordentligt.\nDu må tage dig sammen.",
	"Den indsats var pinlig.\nDe andre bar læsset, mens du sakkede bagud.\nGør det bedre, ellers lad være.",
	"Du lavede fejl på fejl i dag.\nPå et tidspunkt holder undskyldninger op med at gælde.\nMød forberedt i morgen for en gangs skyld.",
	"Jeg bad om resultater, ikke kaos.\nDu skabte flere problemer end løsninger.\nDet må ikke ske igen.",
	"Hvis det her er dit bedste, er det ikke nok.\nDet var frustrerende at se på i dag.\nJeg forventer en klar forbedring i morgen.",
	"Du var væk hele vagten.\nJeg har brug for folk, jeg kan stole på, ikke statister.\nTænk over det i aften.",
	"I dag sejlede fra start til slut.\nDin indsats var en stor del af det.\nMød klar næste gang."
  ],
  "ok": [
	"HVAD LAVER DU???\nHaha, rolig - det gik faktisk fint.\nFå bedre søvn i morgen, jeg vil se en perfekt indsats.",
	"Jeg var lige ved at gå i panik.\nMen du klarede det faktisk fint.\nLad os stramme det op i morgen.",
	"Et øjeblik troede jeg, vi var færdige.\nMen du reddede den til sidst.\nGodt comeback—start bedre i morgen.",
	"Du elsker virkelig at stresse mig, hva?\nMen resultatet var okay.\nLad os gå efter noget bedre i morgen.",
	"Jeg var klar til at holde en tale.\nHeldigvis fik du styr på det.\nKom fokuseret i morgen.",
	"Interessant strategi i dag.\nDet virkede bedre end forventet.\nMindre kaos, mere stabilitet i morgen.",
	"Jeg havde mange spørgsmål i dag.\nDe fleste blev besvaret til sidst.\nGodt nok—men du kan gøre det bedre i morgen.",
	"Du arbejder som om mandag er ulovlig.\nMen jobbet blev gjort, så fair nok.\nMere energi i morgen.",
	"Jeg var tæt på at skrive dit navn ned.\nMen du sluttede stærkt.\nHold det niveau hele vagten i morgen.",
	"Det var en mærkelig indsats.\nIkke dårlig, ikke fantastisk—bare... speciel.\nLad os gøre i morgen mindeværdig på den gode måde."
  ],
  "good": [
	"Flot arbejde i dag.\nDu holdt fokus og klarede det hele godt.\nNyd aftenen - du har fortjent det.",
	"Jeg lagde mærke til din indsats i dag.\nDen stabilitet betyder noget.\nKom igen i morgen med samme energi.",
	"Stærkt arbejde i dag.\nDu løftede holdet bare ved din indsats.\nFå hvilet og ses i morgen.",
	"Du var stabil, skarp og produktiv.\nDet er præcis det, jeg har brug for.\nRigtig godt arbejde.",
	"Virkelig solid indsats i dag.\nDu håndterede presset uden at falde i tempo.\nVær stolt af det.",
	"Tak for indsatsen i dag.\nDet blev bemærket.\nGod aften—lad op til i morgen.",
	"Imponerende arbejde i dag.\nBåde kvalitet og attitude var i top.\nByg videre på det i morgen.",
	"Det var en professionel indsats.\nDu løste problemer og holdt tingene i gang.\nFremragende arbejde.",
	"Du kom med god energi i dag.\nFolk lægger mere mærke til det, end du tror.\nSes i morgen.",
	"Stærk afslutning på dagen.\nDu holdt fokus hele vejen.\nDet er standarden."
  ]
}

var boss_feedback := [
	"En ting mere inden du går.\nEn klient har sendt noget feedback.\nTag et øjeblik og læs det.",
	"Før du stempler ud,\nder er kommet noget feedback fra en klient.\nSørg for at tjekke det.",
	"Det var alt for i dag.\nEn klient har sendt feedback.\nBrug det i morgen.",
	"Lige en hurtig besked inden du går.\nDer er feedback fra en klient på vej.\nGiv det et grundigt kig.",
	"Godt arbejde med at afslutte dagen.\nJeg har modtaget feedback fra en klient.\nLæs det når det kommer.",
	"Vi er færdige med vagten.\nDer er feedback fra en klient lige efter dette.\nVær opmærksom på detaljerne.",
	"Inden dagen slutter,\nkan du forvente feedback fra en klient.\nDet kan hjælpe i morgen.",
	"Godt, det er afsluttet.\nNu kommer der lidt feedback fra en klient.\nTag det seriøst.",
	"Du kan slappe af om et øjeblik.\nFørst sender jeg noget feedback fra en klient.\nTjek det nedenfor.",
	"Dagen er afsluttet.\nDer er kommet feedback fra en klient.\nBrug det til at forbedre næste vagt."
]

var boss_fired := [
	"Det her fungerer ikke længere.\nVi har givet dig chancer nok, og der er ingen udvikling.\nDu er færdig her – aflever dine ting inden du går.",
	"Jeg går direkte til sagen.\nDin indsats matcher ikke det niveau, vi kræver.\nI dag bliver din sidste arbejdsdag.",
	"Vi har haft den samme samtale for mange gange.\nForventningerne er ikke blevet mødt.\nDerfor stopper dit ansættelsesforhold nu.",
	"Jeg havde håbet på en forbedring.\nDen kom aldrig.\nPak sammen – vi går hver til sit fra i dag.",
	"Det her er ikke personligt.\nMen jobbet bliver ikke løst godt nok.\nVi afslutter samarbejdet med øjeblikkelig virkning.",
	"Jeg har brug for folk, jeg kan regne med.\nDet har du ikke vist, at jeg kan.\nDu skal ikke møde ind igen fra i morgen.",
	"Resultaterne taler for sig selv.\nVi kan ikke fortsætte sådan her.\nDin ansættelse ophører i dag.",
	"Jeg vil ikke pakke det ind.\nDet her har ikke fungeret i noget tid.\nDu er opsagt med virkning fra nu.",
	"Vi har vurderet situationen grundigt.\nDer er ikke grundlag for at fortsætte samarbejdet.\nTak for din tid – det slutter her.",
	"Jeg forventede mere stabilitet, mere ansvar og bedre kvalitet.\nDet fik jeg ikke.\nDerfor er det slut fra i dag."
]

func _ready():
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func fetch_mails(day = 1, count = 10) -> bool:
	if fetch_in_progress:
		return true

	var excluded_id_lookup := {}

	for finished in finished_mails:
		var finished_id := int(finished.get("id", -1))
		if finished_id != -1:
			excluded_id_lookup[finished_id] = true

	for unanswered in mails:
		var unanswered_id := int(unanswered.get("id", -1))
		if unanswered_id != -1:
			excluded_id_lookup[unanswered_id] = true

	var excluded_ids := []
	for id in excluded_id_lookup.keys():
		excluded_ids.append(int(id))
		
	var data = {"count" : int(clamp(count, 1, 20)), "receivedMailIds" : excluded_ids, "day" : day}

	var payload = JSON.stringify(data)
	
	var err := http.request(API_URL + "/spam-mails/batch", headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		emit_signal("mails_fetched", false, 0)
		return false

	fetch_in_progress = true
	return true
	
func _on_request_completed(_result, response_code, _headers, body):
	var text = body.get_string_from_utf8()
	var added_count := 0
	fetch_in_progress = false

	if response_code == 200:
		var data = JSON.parse_string(text)
		
		if typeof(data) != TYPE_DICTIONARY:
			emit_signal("mails_fetched", false, 0)
			return

		if "mails" not in data.keys():
			emit_signal("mails_fetched", false, 0)
			return

		for incoming_mail in data["mails"]:
			var mail_id := int(incoming_mail.get("id", -1))

			mails.append(incoming_mail)
			added_count += 1

		emit_signal("mails_fetched", true, added_count)
	else:
		print("Mail fetch failed")
		emit_signal("mails_fetched", false, 0)

func _has_mail_id(mail_id: int) -> bool:
	for mail in mails:
		if int(mail.get("id", -1)) == mail_id:
			return true
	return false
