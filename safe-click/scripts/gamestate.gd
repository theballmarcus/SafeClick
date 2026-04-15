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

var boss_comments := {
  "bad": [
	"What was that today?\nI’ve seen beginners do better work than this.\nDo not come back tomorrow with the same attitude.",
	"You managed to turn simple tasks into a disaster.\nI shouldn’t have to babysit you every shift.\nFigure it out before you waste more of my time.",
	"Completely unacceptable performance today.\nYou were slow, distracted, and careless.\nFix it immediately or we have a real problem.",
	"I don’t know what you were thinking all day.\nNothing was done properly.\nYou need to seriously wake up.",
	"That effort was embarrassing.\nEveryone else carried the load while you dragged behind.\nDo better or don’t bother.",
	"You made mistake after mistake today.\nAt some point excuses stop mattering.\nCome prepared tomorrow for once.",
	"I asked for results, not chaos.\nYou created more problems than solutions.\nThat cannot happen again.",
	"If this is your best, it’s not enough.\nToday was frustrating to watch.\nI expect a complete turnaround tomorrow.",
	"You were checked out the entire shift.\nI need workers I can rely on, not passengers.\nThink hard about that tonight.",
    "Today was a mess from start to finish.\nYour performance was the biggest part of it.\nShow up ready next time."
  ],
  "ok": [
	"WHAT ARE YOU DOING???\nPsych, you did okay though.\nGet better sleep tomorrow, I need a perfect performance.",
	"I almost came over there to panic.\nThen I looked closer—you actually handled it fine.\nLet’s sharpen it up tomorrow.",
	"For a second, I thought we were doomed.\nTurns out you saved it in the end.\nNice recovery, but start stronger tomorrow.",
	"You really enjoy stressing me out, huh?\nStill, the results were decent.\nLet’s aim for great instead of decent tomorrow.",
	"I was ready to give a speech.\nLuckily, you pulled it together.\nCome in focused tomorrow and make it easy on me.",
	"Bold strategy today.\nSomehow it worked better than I expected.\nLet’s use less chaos and more consistency tomorrow.",
	"I had questions all day.\nBy the end, most of them were answered.\nGood enough—but I know you can level up tomorrow.",
	"You move like Mondays are illegal.\nBut the work got done, so I’ll allow it.\nBring more energy tomorrow.",
	"I nearly wrote your name in my complaint notebook.\nThen you finished strong.\nKeep the strong part for the whole shift tomorrow.",
    "That was a weird performance.\nNot bad, not amazing, just... memorable.\nLet’s make tomorrow memorable for better reasons."
  ],
  "good": [
	"Great job today.\nYou stayed focused and handled everything well.\nEnjoy your evening—you earned it.",
	"I noticed the effort you gave all day.\nThat kind of consistency matters.\nCome back tomorrow with the same energy.",
	"Strong work today.\nYou made the team better just by how you showed up.\nRest up and see you tomorrow.",
	"You were reliable, sharp, and productive.\nThat’s exactly what I need.\nExcellent job today.",
	"Really solid performance today.\nYou handled pressure without slowing down.\nBe proud of that work.",
	"Thank you for the effort today.\nIt didn’t go unnoticed.\nHave a good night and recharge.",
	"You did impressive work today.\nThe quality and attitude were both top level.\nKeep building on that tomorrow.",
	"That was a professional performance.\nYou solved problems and kept things moving.\nOutstanding job.",
	"You brought great energy today.\nPeople notice that more than you think.\nSee you tomorrow.",
    "Excellent finish to the day.\nYou stayed locked in until the end.\nThat’s the standard right there."
  ]
}

var boss_feedback := [
	"One more thing before you go.\nI’ve got some feedback for you.\nTake a second and read it.",
	"Before you clock out completely,\nthere’s some feedback coming your way.\nMake sure you check it.",
	"That’s all for today.\nNow I’m sending you some feedback.\nUse it well tomorrow.",
	"Quick heads-up before you leave.\nSome feedback is coming next.\nGive it a proper look.",
	"Nice work wrapping up today.\nI’ve got feedback ready for you.\nRead through it when it arrives.",
	"We’re done for the shift.\nYour feedback is coming right after this.\nPay attention to the details.",
	"Before the day ends,\nexpect some feedback from me.\nIt’ll help for tomorrow.",
	"Good, that’s a wrap.\nNow comes a bit of feedback.\nTake it seriously.",
	"You can relax in a second.\nFirst, I’m sending some feedback.\nCheck it out below.",
    "End of day complete.\nYour feedback is coming now.\nUse it to improve next shift."
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
			if mail_id == -1:
				continue
			if _has_mail_id(mail_id):
				continue
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
