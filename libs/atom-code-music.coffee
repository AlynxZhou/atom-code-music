{CompositeDisposable} = require("atom")
Base64Binary = require("./base64binary")
Piano = require("./acoustic_grand_piano-ogg")
Converter = require("./converter")

class AtomCodeMusic
	constructor: ->
		@i = 0
		@j = 0
		@switch = false
		@context = new AudioContext()
		@gainNode = @context.createGain()
		@gainNode.connect(@context.destination)
		@gainNode.gain.value = 2
		@notes = new Object()
		@sources = new Array()
		@subscriptions = new CompositeDisposable()
		for note of Piano then do (note) =>
			@context
			.decodeAudioData(Base64Binary
			.decodeArrayBuffer(Piano[note]
			.split("data:audio/ogg;base64,")[1]),
			(soundBuffer) => @notes[note] = soundBuffer)

	activate: ->
		@subscriptions.add(atom.commands.add("atom-workspace",
			"atom-code-music:toggle":  @toggle))
		@subscriptions.add(atom.commands.add("atom-text-editor",
			"atom-code-music:convert": @convert))
		@changeMode()
		@subscriptions.add(atom.config.onDidChange("atom-code-music.workMode", @changeMode))

	deactivate: ->
		@subscriptions.dispose()

	changeMode: =>
		@workMode = atom.config.get("atom-code-music.workMode")
		switch (@workMode)
			when "Real Piano Mode"
				@keysToNotes = require("./keys-notes")
			when "Music Box Mode"
				@sheetsList = require("./sheets-list")
				@sheet = require("#{@sheetsList[@i]}")
		console.log("atom-code-music: Changed mode into #{@workMode}!")

	noteOn: (event) =>
		# console.log(event.code)
		switch (@workMode)
			when "Music Box Mode"
				if event.code not in ["ControlLeft", "ControlLeft", "AltLeft", "AltRight", "ShiftLeft", "ShiftRight"]
						if @j >= @sheet.length
							@i++
							if @i >= @sheetsList.length
								@i = 0
							@sheet = require("#{@sheetsList[@i]}")
							@j = 0
						for note in @sheet[@j]
							@gainNode.gain.value = 2 / @sheet[@j].length
							source = @context.createBufferSource()
							source.connect(@gainNode)
							source.buffer = @notes[note]
							source.start(0)
							@sources.push(@source)
						@j++
			when "Real Piano Mode"
				if event.code of @keysToNotes
					@source = @context.createBufferSource()
					@source.connect(@gainNode)
					@source.buffer = @notes[@keysToNotes[event.code]]
					@source.start(0)

	noteOff: (event) =>
		switch (@workMode)
			when "Music Box Mode"
				for source in @sources
					source?.stop(@context.currentTime + 0.5)
			when "Real Piano Mode"
				if event.code of @keysToNotes
					@source?.stop(@context.currentTime + 0.5)

	toggle: =>
		@switch = not @switch
		if @switch
			atom.views.getView(atom.workspace)
			.addEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace)
			.addEventListener("keyup", @noteOff)
			console.log("atom-code-music: Started in #{@workMode}!")
		else
			atom.views.getView(atom.workspace)
			.removeEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace)
			.removeEventListener("keyup", @noteOff)
			console.log("atom-code-music: Stopped!")

	convert: =>
		i = 0
		oldEditor = atom.workspace.getActiveTextEditor()
		lineCount = oldEditor.getScreenLineCount()
		lineConverter = new Converter()
		(atom.workspace.open()).then(->
			newEditor = atom.workspace.getActiveTextEditor()
			newEditor.insertText("module.exports = [\n")
			while i < lineCount
				newEditor.insertText(lineConverter.handleText(i, oldEditor.lineTextForScreenRow(i)))
				i++
			newEditor.insertText("]\n")
		)


module.exports = AtomCodeMusic
