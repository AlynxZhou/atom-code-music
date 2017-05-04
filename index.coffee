AtomCodeMusic = require("./libs/atom-code-music")

module.exports =
	config:
		timbre:
			type: "string"
			title: "Timbre"
			description: "Timbre of the plugin when there is no timbre recorded in the sheet."
			enum: [
				{value: "Piano", description: "Piano"},
				{value: "Marimba", description: "Marimba"},
				{value: "Random", description: "Choose a timbre for a music sheet randomly."}
			]
			default: "Random"
		workMode:
			type: "string"
			title: "Work Mode"
			description: "Work mode of the plugin."
			enum: [
				{value: "Real Piano Mode", description: "Real piano mode just like playing a piano."},
				{value: "Music Box Mode", description: "Play built-in music sheets like a music box."}
			]
			default: "Music Box Mode"
		customSheets:
			type: "string"
			title: "Custom Sheets"
			description: "Add path for each of your custom sheets, split by `,`."
			default: ''

	atomCodeMusic: new AtomCodeMusic()

	activate: ->
		@atomCodeMusic?.activate()

	deactivate: ->
		@atomCodeMusic?.deactivate()
