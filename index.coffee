AtomMidiPiano = require("./lib/atom-midi-piano")

module.exports =
	config:
		workMode:
			type: "string"
			title: "Work Mode"
			description: "Work mode of the piano plugin."
			enum: [
				{value: "Real Piano Mode", description: "Real piano mode just like playing a piano."},
				{value: "Music Box Mode", description: "Play built-in music sheets like a music box."}
			]
			default: "Music Box Mode"

	atomMidiPiano: new AtomMidiPiano()

	activate: ->
		@atomMidiPiano?.activate()

	deactivate: ->
		@atomMidiPiano?.deactivate()
