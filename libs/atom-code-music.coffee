{CompositeDisposable} = require("atom")
base64Binary = require("./base64binary")
timbres =
	"Piano": require("./timbres/acoustic_grand_piano-ogg")
	"Marimba": require("./timbres/marimba-ogg")
Converter = require("./converter")
sheetsList = require("./sheets-list")
keysNotes = require("./keys-notes")

class AtomCodeMusic
	constructor: ->
		@i = 0
		@switch = false
		@context = new AudioContext()
		@gainNode = @context.createGain()
		@gainNode.connect(@context.destination)
		@gainNode.gain.value = 1
		@notes = new Object()
		@sources = new Array()
		@workMode = ""
		@timbre = ""
		@customSheets = ""
		@sheet = ""
		@lineConverter = new Converter()
		@subscriptions = new CompositeDisposable()
		# Use two closure wrappers to save the status.
		# Because decodeAudioData() is an async method.
		for timbre of timbres then do (timbre) =>
			@notes[timbre] = new Array()
			for pitch of timbres[timbre] then do (pitch) =>
				@context
				.decodeAudioData(base64Binary
				.decodeArrayBuffer(timbres[timbre][pitch]
				.split("data:audio/ogg;base64,")[1]),
				(audioBuffer) =>
					@notes[timbre][pitch] = audioBuffer)

	activate: ->
		@subscriptions.add(atom.commands.add("atom-workspace",
			"atom-code-music:toggle":  @toggle))
		@subscriptions.add(atom.commands.add("atom-text-editor",
			"atom-code-music:convert": @convert))
		@changeMode()
		@changeTimbre()
		@changeSheetsList()
		@subscriptions.add(atom.config.onDidChange("atom-code-music.workMode", @changeMode))
		@subscriptions.add(atom.config.onDidChange("atom-code-music.timbre", @changeTimbre))
		@subscriptions.add(atom.config.onDidChange("atom-code-music.customSheets", @changeSheetsList))

	deactivate: ->
		@subscriptions.dispose()

	changeMode: =>
		@workMode = atom.config.get("atom-code-music.workMode")
		if @workMode is "Music Box Mode"
			while @sheet is ""
				try
					@sheet = require("#{sheetsList[Math.floor(Math.random() * sheetsList.length)]}")
				catch e
					@sheet = ""
		console.log("atom-code-music: Set mode into #{@workMode}!")

	changeTimbre: =>
		@timbre = atom.config.get("atom-code-music.timbre")
		if @timbre is "Random"
			tempTimbres = (timbre for timbre of timbres)
			@timbre = (timbre for timbre of timbres)[Math.floor(Math.random() * tempTimbres.length)]
		console.log("atom-code-music: Set timbre into #{@timbre}!")

	changeSheetsList: =>
		@customSheets = atom.config.get("atom-code-music.customSheets")
		if @customSheets.length
			@customSheets = @customSheets.replace(/, /g, ',')
			sheetsList = sheetsList.concat(@customSheets.split(','))
		console.log("atom-code-music: Set custom sheets into #{@customSheets}!")

	noteOn: (event) =>
		# console.log(event.code)
		switch (@workMode)
			when "Music Box Mode"
				if event.code not in ["ControlLeft", "ControlRight", "AltLeft", "AltRight", "ShiftLeft", "ShiftRight"]
					if @i >= @sheet.length
						@sheet = ""
						while @sheet is ""
							try
								@sheet = require("#{sheetsList[Math.floor(Math.random() * sheetsList.length)]}")
							catch e
								@sheet = ""
						@changeTimbre()
						@i = 0
					for note in @sheet[@i]
						if note["timbre"] isnt ""
							@timbre = note["timbre"]
						if note["pitch"] of @notes[@timbre]
							@gainNode.gain.value = note["loudness"]
							source = @context.createBufferSource()
							source.connect(@gainNode)
							source.buffer = @notes[@timbre][note["pitch"]]
							source.start(0)
							@sources.push(source)
					@i++
			when "Real Piano Mode"
				if event.code of keysNotes
					source = @context.createBufferSource()
					source.connect(@gainNode)
					source.buffer = @notes[@timbre][keysNotes[event.code]]
					source.start(0)
					@sources.push(source)

	noteOff: (event) =>
		switch (@workMode)
			when "Music Box Mode"
				for source in @sources
					source?.stop(@context.currentTime + 0.5)
			when "Real Piano Mode"
				for source in @sources
					if event.code of keysNotes
						source?.stop(@context.currentTime + 0.5)

	toggle: =>
		@switch = not @switch
		if @switch
			atom.views.getView(atom.workspace).addEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace).addEventListener("keyup", @noteOff)
			console.log("atom-code-music: Started!")
		else
			atom.views.getView(atom.workspace).removeEventListener("keydown", @noteOn)
			atom.views.getView(atom.workspace).removeEventListener("keyup", @noteOff)
			console.log("atom-code-music: Stopped!")

	convert: =>
		i = 0
		oldEditor = atom.workspace.getActiveTextEditor()
		lineCount = oldEditor.getScreenLineCount()
		(atom.workspace.open()).then(=>
			newEditor = atom.workspace.getActiveTextEditor()
			newEditor.insertText("module.exports = [\n")
			while i < lineCount
				newEditor.insertText(@lineConverter.handleText(i, oldEditor.lineTextForScreenRow(i)))
				i++
			newEditor.insertText("]\n")
		)


module.exports = AtomCodeMusic
