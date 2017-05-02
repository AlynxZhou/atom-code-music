AtomCodeMusic = require("./libs/atom-code-music")

module.exports =
	config:
		workMode:
			type: "string"
			title: "Work Mode"
			description: "Work mode of the plugin."
			enum: [
				{value: "Real Piano Mode", description: "Real piano mode just like playing a piano."},
				{value: "Music Box Mode", description: "Play built-in music sheets like a music box."}
			]
			default: "Music Box Mode"

	atomCodeMusic: new AtomCodeMusic()

	activate: ->
		@atomCodeMusic?.activate()

	deactivate: ->
		@atomCodeMusic?.deactivate()
