window.$coffee = {}

$coffee.compile = (code, bare) ->
    # TODO: try/catch errors
    js = CoffeeScript.compile code, bare: (bare ? false)
    js

$coffee.evaluate = (code, js) ->
    # Pass js if don't want to recompile.
    js = $coffee.compile code unless js
    eval js
    js
    
class Compiler
    
    constructor: (@spec) ->
        @id = @spec.id
        @head = document.head
        
    compile: (@code) ->
        console.log "Compile #{@id}"
        script = @findScript()
        @head.removeChild script[0] if script.length
        @element = $ "<script>",
            type: "text/javascript"
            "data-url": @id
        compile = @spec.compile ? $coffee.compile
        @js = compile @code
        @element.text @js
        @head.appendChild @element[0]
    
    findScript: ->
        $("script[data-url='#{@id}']")
    


class Evaluator
    
    # Works:
    # switch, class
    # block comments set $coffee.eval, but not processed because comment.
    
    # Not supported:
    # unindented block string literals
    # unindented objects literals not assigned to variable (sees fields as different objects but perhaps this is correct?)
    # Destructuring assignments may not work for objects
    # ZZZ Any other closing chars (like parens) to exclude?
    
    noEvalStrings: [")", "]", "}", "\"\"\"", "else", "try", "catch", "finally", "alert", "console.log"]  # ZZZ better name?
    lf: "\n"
    
    constructor: (@spec) ->
        @id = @spec.id
        @js = null
    
    compile: (@code, recompile=true) ->
        $coffee.evaluating = @id
        
        #recompile = true
        
        stringify = true #ZZZ test
        compile = recompile or not(@evalLines and @js)
        if compile
            codeLines = @code.split @lf
            # $coffee.eval needs to be global so that we can access it after eval.
            $coffee.eval ?= {}
            $coffee.eval["#{@id}"] = ((if @isComment(l) and stringify then l else "") for l in codeLines)
            @evalLines = ((if @noEval(l) then "" else "$coffee.eval['#{@id}'][#{n}] = ")+l for l, n in codeLines).join(@lf)
            js = null
        else
            js = @js
            
        try
            # Evaluated lines will be assigned to $coffee.eval.
            evaluate = @spec.evaluate ? $coffee.evaluate
            @js = evaluate @evalLines, js
        catch error
            console.log "eval error", error
            #alert error
        
        @resultArray = $coffee.eval["#{@id}"]
        @result = @stringify @resultArray
        
        return @result #unless stringify  # ZZZ perhaps break into 2 steps (separate calls): process then stringify?
        
    stringify: (resultArray) ->
        result = ((if e is "" then "" else (if e and e.length and e[0] is "#" then e else @objEval(e))) for e in resultArray)
    
    noEval: (l) ->
        # ZZZ check tabs?
        return true if (l is null) or (l is "") or (l.length is 0) or (l[0] is " ") or (l[0] is "#") or (l.indexOf("#;") isnt -1)
        # ZZZ don't need trim for comment?
        for r in @noEvalStrings
            return true if l.indexOf(r) is 0
        false
    
    isComment: (l) ->
        return l.length and l[0] is "#" and (l.length<3 or l[0..2] isnt "###")
        
    findStr: (str) ->
        p = null
        for e, idx in @resultArray
            p = idx if (typeof e is "string") and e is str
        p
    
    objEval: (e) ->
        try
            line = $inspect2(e, {depth: 2})
            line = line.replace(/(\r\n|\n|\r)/gm,"")
            return line
        catch error
            return ""


$coffee.compiler = (spec) -> new Compiler spec
$coffee.evaluator = (spec) -> new Evaluator spec
