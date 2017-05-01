AtomMidiPiano = require("./lib/atom-midi-piano")

module.exports =
	atomMidiPiano: new AtomMidiPiano()

	activate: ->
		@atomMidiPiano?.activate()

	deactivate: ->
		@atomMidiPiano?.deactivate()
