{CompositeDisposable} = require("atom")
Base64Binary = require("./base64binary")
Piano = require("./acoustic_grand_piano-ogg")
KeysNotes = require("./keys-notes")

class AtomMidiPiano
	constructor: ->
		@switch = false
		@context = new AudioContext()
		@gainNode = @context.createGain()
		@gainNode.connect(@context.destination)
		@gainNode.gain.value = 2
		@notes = new Object()
		@keysToNotes = KeysNotes
		@subscriptions = new CompositeDisposable()
		for note of Piano then do (note) =>
			@context
			.decodeAudioData(Base64Binary
			.decodeArrayBuffer(Piano[note]
			.split("data:audio/ogg;base64,")[1]),
			(soundBuffer) => @notes[note] = soundBuffer)

	activate: ->
		@subscriptions.add(atom.commands.add("atom-workspace",
			"atom-midi-piano:toggle": => @toggle()))

	deactivate: ->
		@subscriptions.dispose()

	noteOn: (event) =>
		console.log(event.code)
		if event.code of @keysToNotes
			@source = @context.createBufferSource()
			@source.connect(@gainNode)
			@source.buffer = @notes[@keysToNotes[event.code]]
			@source.start(0)

	noteOff: (event) =>
		if event.code of @keysToNotes
			@source?.stop(@context.currentTime + 0.5)

	toggle: ->
		@switch = not @switch
		if @switch
			atom.views.getView(atom.workspace)
			.addEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace)
			.addEventListener("keyup", @noteOff)
			console.log("Atom-MIDI-Piano started!")
		else
			atom.views.getView(atom.workspace)
			.removeEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace)
			.removeEventListener("keyup", @noteOff)
			console.log("Atom-MIDI-Piano stopped!")

module.exports = AtomMidiPiano
