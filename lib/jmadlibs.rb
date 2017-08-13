# Features:
#   * alternatives: {option1|option2}
#
#   * optionals: [optionaltext]
#     > weighted optionals: [optionaltext%chance]
#
#   * substitutions: <wordlist>
#   * post-processed substitutions:
#     > <wordlist%a> prepends a/an based on first letter of returned word
#     > capitalised substitutions: <Wordlist>
#
#   * joins between two lists: <lista+listb>

# All of the above can be combined and appear in the results of a parsing,
# so having any operator appear in a substitution word list is possible.

# TODO:
# * Currently, {{alt aa|alt ab}|{alt ba|alt bb}} will fail. Regex needs work.
# * add pluralisation: bike->bikes, boss->bosses, fox->foxes, etc. https://en.wikipedia.org/wiki/English_plurals
# * \ escaping of token signifiers. For instance, \[thing] treated as plaintext
# * Redo <lista+listb> parsing to use list lengths and random index generation rather than current concatenation of
#   copies.
# * Look into allowing $0-9 specifiers per-list in <lista+listb> constructions


class JMadlibs
  def initialize(pattern=nil, library=nil, variantString = "")
    @loglevels = {0 => "NONE", 1 => "ERROR", 2 => "WARN", 3 => "INFO", 4 => "DEBUG", 5 => "ALL"}
	@loglevel = 3
    @rng = Random.new
    setPattern(pattern)
    setLibrary(library)
    setVariants(variantString)
  end

  def log(msg, priority=5)
    if priority.is_a? String then priority = @loglevels.key(priority) end
	if priority <= @loglevel
	  puts "JMadlibs: [" + @loglevels[priority] + "] " + msg
	end
  end

  def addList(name, wordlist)
    if @library.nil? then @library = {} end
    log "Adding list '" + name + "'", "DEBUG"
    @library[name] = wordlist
  end

  def setPattern(pattern)
    if !pattern.nil? then log "Pattern set to '" + pattern + "'", "DEBUG" end
	@pattern = pattern
  end

  def setLibrary(library)
    if !library.nil?
      log "Library updated", "DEBUG"
      @library = library
	end
  end

  def setVariants(variantString)
    @variants = variantString
  end

  def setLogLevel(loglevel)
    if loglevel.is_a? String then loglevel = @loglevels.key(loglevel) end
    @loglevel = loglevel
	log "Loglevel set to '" + @loglevels[loglevel] +"'", "INFO"
  end

  def loadList(filename)
    if File.file?(filename)
      log "Loading word lists from " + filename, "INFO"
      @library = {}
      currentList = ""
      currentListContents = []

      File.foreach(filename).with_index do |line|
        line = line.strip
        if line != "" and !line.start_with?('#')
          matched = /^==(.+)==$/.match(line)
          if !matched.nil? # new list identifier
            if currentList != "" # save old list, if one exists.
              addList(currentList, currentListContents)
            end
            currentList = matched[1] # update working targets for new list
            currentListContents = []
          elsif currentList == "" # we have no current list; this must be a pattern
            setPattern(line)
          else # word to be added to current list
            currentListContents.push(line)
          end
        end
      end
      addList(currentList, currentListContents)
    else
      log "Unable to open file.", "WARN"
    end
  end

  def anify(word) # If word begins with a vowel, prefix 'an ', else prefix 'a '
    if (/^[aeiou]/.match(word).nil?)
      result = "a " + word
	else
      result = "an " + word
	end

    return result
  end

  def getSpecified(word, specifier = nil) # get the correct representation of a word
    #TODO: Convert ex. marry^marries^married^marrying to specified subword, return first if no specifier

    # find default
    options = word.count("\^")

    if options == 0 # no variants exist
      return word
    end

    default = word[0..word.index("^")-1]

    if specifier.nil?
      return default
    end

    variant = 0

    if !specifier.index(/[0-9]/).nil? 
      variant = specifier.to_i
    else
      variant = @variants.index(specifier)
    end

    if variant.nil?
      log "Unknown variant identifier '" + specifier + "', using default.", 3
      return default
    end

    start = 0

    if variant >= options 
      log "Unknown variant identifier '" + variant.to_s + "', using default.", 3
      return default
    end


    for i in 0..variant # find start of correct option
       start = word.index("^", start+1)
    end

    finish = word.index("^", start+1)

    result = ""

    if finish.nil?
      result = word[start+1..-1]
    else
      result = word[start+1..finish-1]
    end

    if result.empty?
      return default
    else
       return result
    end
  end

  def pluralise(word)
    # TODO
    # add s by default
    # (lf)(fe?) -> ves
	# y -> ies
	# o -> oes
    # (se?)(sh)(ch)

    # this is a pretty big problem!  POssibly solvable with getSpecified instead.
    return word
  end

  def resolve_substitution(target)
    up = false
    specifiers = ""

    # do we need to do post-processing?
    post = target.rindex(/\$[a-zA-Z0-9]+/)

    if !post.nil?
      specifiers = target.slice(post+1, target.length - post - 1)
      variant = specifiers.scan(/[a-z0-9]/)
      specifiers = specifiers.scan(/[A-Z]/)
      target = target.slice(0, post)
    end

    if !(/^[A-Z]/.match(target).nil?) # do we need to capitalise?
      target = target.downcase
      up = true
    end

    # are we selecting from multiple lists?
    mult = target.index /\+/

    if mult.nil? # only one list
      if @library[target].nil?
        log "Missing wordlist: " + target, 2
        return "MISSING"
      end
      result = parse_pattern(@library[target].sample(random: @rng))

    else # more than one list
      multlist = []
      listnames = []

      if false # testing new method

      # as long as we still have alternatives, keep adding them to listnames
      while !mult.nil?
        listnames << target.slice(0, mult)
	target = target.slice(mult+1, target.length - mult - 1)
        mult = target.index /\+/
      end
      listnames << target # append final alternative

      # combine lists for sampling
      listnames.each do |list|
        if !@library[list].nil? then multlist += @library[list] end
      end

      if multlist.length == 0 # no valid options found
        log "Missing wordlist: " + target, 2
        return "MISSING"
      end
      result = parse_pattern(multlist.sample(random: @rng))

      else # Test of new routine for sampling multiple lists
        while !mult.nil?
          listnames << target.slice(0, mult)
          target = target.slice(mult+1, target.length - mult - 1)
          mult = target.index /\+/
        end
        listnames << target # append final alternative

        # Find total count of options
        max = 0

        listnames.each do |list|
          if !@library[list].nil? then max += @library[list].length end
        end

        # Pick index within overall size
        index = @rng.rand(max)

        # iterate through lists until we find the list the index fits into
        listnames.each do |list|
          if index >= @library[list].length # Not in this list, so discard its indices
            index -= @library[list].length
          else
            result = parse_pattern(@library[list][index]) # in this list; return index
            break
          end            
        end
      end
    end

    # Dealing with possible variant suffixes

    if result.count("\^") > 0 # if we have options...
      if !variant.nil? and variant.length > 0 # get variant if it exists
        variant = variant.slice!(0)
        result = getSpecified(result, variant)
      else # get the default
        result = getSpecified(result)
      end
    end

    # do post-processing

    if specifiers.include? "A"
      result = anify(result)
    end

    if specifiers.include? "U"
      result[0] = result[0].upcase
    end

    return result
  end

  def resolve_alternative(target)
    options = []
    while target.length > 0 # split into options
      ind = target.index /\|/ # needs rewriting to parse (a|(ba|bb)) and similar

      if ind.nil? # only one option
        options << target
        target = ""
      else
        options << target.slice(0, ind)
        target = target.slice(ind+1, target.length - ind - 1)
      end
    end

    result = options.sample(random: @rng)
    return parse_pattern(result)
  end

  def resolve_optional(target)
    chance = 50

    ind = target.index("%") # specified chance?

    if !ind.nil?
      chance = target.slice(ind+1, target.length - ind - 1).to_i
      target = target.slice(0, ind)
    end

    result = ""

    if @rng.rand(100) <= chance
      result = target
    end

    return parse_pattern(result)
  end

  def sampledict(target)
    return resolve_substitution(target)
  end

  def parse_pattern(target)
    tokens = []
    flags = []
	escaped = false

    while target.length > 0
      ind = target.index /[<{\[]/

      if ind.nil? # only plain text remains
        tokens << target
        target = ""
        flags << "p"

      elsif ind > 0 # plain text with some other token following
        tokens << target.slice(0,ind)
        target = target.slice(ind, target.length - ind)
        flags << "p"

      else # non-plaintext token
        type = ""

        if target.slice(0) == "<"
          ind = target.index(">")
          type = "s"
        elsif target.slice(0) == "{"
          ind = target.index("}")
          type = "a"
        elsif target.slice(0) == "["
          ind = target.index("]")
          type = "o"
        end

        if ind.nil?
          log "'" + target +"' escaped or missing terminator, treating as plaintext.", "INFO"
          tokens << target
          target = ""
          flags << "p"
        else
          tokens << target.slice(1, ind-1)
          target = target.slice(ind+1, target.length - ind+1)
          flags << type
        end
      end
    end

    # parse tokens
    tokens.each_with_index { |token, index|
      if flags[index] == "a"
        tokens[index] = resolve_alternative(token)
      elsif flags[index] == "o"
        tokens[index] = resolve_optional(token)
      elsif flags[index] == "s"
        tokens[index] = resolve_substitution(token)
      end
    }

    # rebuild string
    result = tokens.join
    return result
  end

  def generate
    if @library.nil?
      log "No library defined.", "WARN"
	  return nil
    elsif @pattern.nil?
      log "No pattern defined.", "WARN"
	  return nil
    else
      return parse_pattern(@pattern)
    end
  end
end
