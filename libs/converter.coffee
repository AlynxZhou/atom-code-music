fs = require("fs")
path = require("path")

class Converter
  constructor: (@oldEditor, @newEditor) ->
    @validArr = [' ', '\r', '\n', '\t', '|',
                 '(', ')', '{', '}', '[', ']', '<', '>',
                 '0', '1', '2', '3', '4', '5', '6', '7',
                 '#1', '#2', '#3', '#4', '#5', '#6', '#7']
    @digitsNotes = JSON.parse(fs.readFileSync(path.join(__dirname, "digits-notes.json")))
    @lineNum = 0
    @keyArr = []
    @parenArr = []
    @keyErrArr = []
    @parenErrArr = []
    @errArrs = []
    @rebuildArr = []
    @fixedArr = []
    @finalArr = []
    @finalJSON = []

  keySplit: (line) ->
    @keyArr = []
    i = 0
    while i < line.length
      switch line[i]
        when '#'
          if i + 1 < line.length
            @keyArr.push('#' + line[i + 1])
          else
            @keyArr.push('#')  # If no if-else it will push a #undefined wrongly, and the error columnNum will be wrong.
          i++
        when ';'
          # @keyArr.push(line[i..line.length])
          i = line.length
        when ' '
          ;
        when '\t'
          ;
        when '\n'
          ;
        when '\r'
          ;
        when ''
          ;
        else
          @keyArr.push(line[i])
      i++
    return @keyArr

  keyCheck: ->
    @keyErrArr = []
    columnNum = 0
    for key in @keyArr
      columnNum += key.length
      if key not in @validArr and key[0] isnt ';'
        @keyErrArr.push([@lineNum, columnNum])
    return @keyErrArr

  parenSplit: ->
    @parenArr = []
    tempArr = []
    i = 0
    while i < @keyArr.length
      switch @keyArr[i]
        when ')'
          if @parenArr.length
            tempArr.push(@keyArr[i])
          else
            @keyArr.unshift('(')
            i = -1
            tempArr = []
            @parenArr = []
        when ']'
          if @parenArr.length
            tempArr.push(@keyArr[i])
          else
            @keyArr.unshift('[')
            i = -1
            tempArr = []
            @parenArr = []
        when '}'
          if @parenArr.length
            tempArr.push(@keyArr[i])
          else
            @keyArr.unshift('{')
            i = -1
            tempArr = []
            @parenArr = []
        when '('
          if tempArr.length
            @parenArr.push(tempArr)
            tempArr = []
          if @keyArr[i...@keyArr.length].indexOf(')') isnt -1
            @parenArr.push(@keyArr[i..i + @keyArr[i...@keyArr.length].indexOf(')')])
            i += @keyArr[i...@keyArr.length].indexOf(')')
          else if @keyArr[@keyArr.length - 1] is '\n'
            @keyArr[@keyArr.length - 1] = ')'
            @keyArr.push('\n')
            @parenArr.push(@keyArr[i...@keyArr.length - 1])
            i = @keyArr.length - 1
          else
            @keyArr.push(')')
            @parenArr.push(@keyArr[i...@keyArr.length])
            i = @keyArr.length
        when '['
          if tempArr.length
            @parenArr.push(tempArr)
            tempArr = []
          if @keyArr[i...@keyArr.length].indexOf(']') isnt -1
            @parenArr.push(@keyArr[i..i + @keyArr[i...@keyArr.length].indexOf(']')])
            i += @keyArr[i...@keyArr.length].indexOf(']')
          else if @keyArr[@keyArr.length - 1] is '\n'
            @keyArr[@keyArr.length - 1] = ']'
            @keyArr.push('\n')
            @parenArr.push(@keyArr[i...@keyArr.length - 1])
            i = @keyArr.length - 1
          else
            @keyArr.push(']')
            @parenArr.push(@keyArr[i...@keyArr.length])
            i = @keyArr.length
        when '{'
          if tempArr.length
            @parenArr.push(tempArr)
            tempArr = []
          if @keyArr[i...@keyArr.length].indexOf('}') isnt -1
            @parenArr.push(@keyArr[i..i + @keyArr[i...@keyArr.length].indexOf('}')])
            i += @keyArr[i...@keyArr.length].indexOf('}')
          else if @keyArr[@keyArr.length - 1] is '\n'
            @keyArr[@keyArr.length - 1] = '}'
            @keyArr.push('\n')
            @parenArr.push(@keyArr[i...@keyArr.length - 1])
            i = @keyArr.length - 1
          else
            @keyArr.push('}')
            @parenArr.push(@keyArr[i...@keyArr.length])
            i = @keyArr.length
        else
          if @keyArr[i][0] isnt ';'
            tempArr.push(@keyArr[i])
      i++
    if tempArr.length
      @parenArr.push(tempArr)
    return @parenArr

  parenCheck: ->
    @parenErrArr = []
    columnNum = 0
    for arr in @parenArr
      if arr[0] in ['(', '[', '{']
        testArr = arr[1...arr.length - 1]
        if testArr.length is 0
          columnNum += 2
          @parenErrArr.push([@lineNum, columnNum])
        else
          j = 0
          while j < testArr.length
            if testArr[j] in ['(', ')', '[', ']', '{', '}']
              columnNum += testArr[0..j].join('').length + 1
              @parenErrArr.push([@lineNum, columnNum])
            j++
      else
        testArr = arr
        j = 0
        while j < testArr.length
          if testArr[j] in ['(', ')', '[', ']', '{', '}']
            columnNum += testArr[0..j].join('').length
            @parenErrArr.push([@lineNum, columnNum])
          j++
      columnNum += arr.join('').length
    return @parenErrArr

  scoreRebuild: ->
    i = 0
    @rebuildArr = []
    rawArr = [' ', '\r', '\n', '\t', '<', '>']
    while i < @keyArr.length
      switch @keyArr[i]
        when '('
          i++
          while @keyArr[i] isnt ')'
            if @keyArr[i] not in rawArr
              @rebuildArr.push('(' + @keyArr[i] + ')')
            else
              @rebuildArr.push(@keyArr[i])
            i++
        when '['
          i++
          while @keyArr[i] isnt ']'
            if @keyArr[i] not in rawArr
              @rebuildArr.push('[' + @keyArr[i] + ']')
            else
              @rebuildArr.push(@keyArr[i])
            i++
        when '{'
          i++
          while @keyArr[i] isnt '}'
            if @keyArr[i] not in rawArr
              @rebuildArr.push('{' + @keyArr[i] + '}')
            else
              @rebuildArr.push(@keyArr[i])
            i++
        else
          @rebuildArr.push(@keyArr[i])
      i++
    return @rebuildArr

  fixKey: ->
    @fixedArr = []
    for key in @rebuildArr
      switch key
        when '(#3)' then @fixedArr.push('(4)')
        when '(#7)' then @fixedArr.push('1')
        when '#3' then @fixedArr.push('4')
        when '#7' then @fixedArr.push('[1]')
        when '[#3]' then @fixedArr.push('[4]')
        when '[#7]' then @fixedArr.push('{1}')
        when '{#3}' then @fixedArr.push('{4}')
        else @fixedArr.push(key)
    return @fixedArr

  buildChord: ->
    @finalArr = []
    chordArr = []
    i = 0
    while i < @fixedArr.length
      switch @fixedArr[i]
        when '>'
          @fixedArr.unshift('<')
          i = -1
          tempArr = []
          @finalArr = []
        when '<'
          i++
          while (@fixedArr[i] isnt '>') and (i < @fixedArr.length)
            if @fixedArr[i] not in [' ', '\r', '\n', '\t']
              chordArr.push(@fixedArr[i])
            i++
        else
          if @fixedArr[i] not in [' ', '\r', '\n', '\t']
            chordArr.push(@fixedArr[i])
      if chordArr.length
        @finalArr.push(chordArr)
        chordArr = []
      i++
    return @finalArr

  handleLine: (line) ->
    @keySplit(line)
    @keyCheck()
    @parenSplit()
    @parenCheck()
    if @keyErrArr.length or @parenErrArr.length
      final = ""
      @errArrs = @errArrs.concat(@keyErrArr)
      @errArrs = @errArrs.concat(@parenErrArr)
      for arr in @errArrs
        final += "###\nError: Line #{arr[0]}, Colomn #{arr[1]}:\n"
        final += "Error: #{line}\n"
        i = 0
        output = "Error: "
        while i < arr[1] - 1
          output += ' '
          i++
        final += "#{output}^\n###\n"
      alert(final)
    else
      @scoreRebuild()
      @fixKey()
      @buildChord()
      for chord in @finalArr
        chordArr = []
        for digit in chord
          note = {"timbre": "", "pitch": "", "loudness": 1};
          try
            note["pitch"] = @digitsNotes[digit]
          catch e
            note["pitch"] = ""
          note["loudness"] = 1 / chord.length
          chordArr.push(note)
        @finalJSON.push(chordArr)

  convert: ->
    lineCount = @oldEditor.getScreenLineCount()
    while @lineNum < lineCount
      @handleLine(@oldEditor.lineTextForScreenRow(@lineNum))
      @lineNum++
    @newEditor.insertText(JSON.stringify(@finalJSON, null, "  "))

module.exports = Converter
