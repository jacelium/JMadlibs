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
# * joins between two lists: <lista+listb>

# All of the above can be combined and appear in the results of a parsing, 
# so having any operator appear in a substitution word list is possible.

# TODO:
# * Currently, {{alt aa|alt ab}|{alt ba|alt bb}} will fail. Regex needs work.
# * add pluralisation: bike->bikes, boss->bosses, fox->foxes, etc. https://en.wikipedia.org/wiki/English_plurals
# * \ escaping of token signifiers. For instance, \[thing] treated as plaintext


class JMadlibs
  def initialize(pattern=nil, library=nil)
    @loglevels = {0 => "NONE", 1 => "ERROR", 2 => "WARN", 3 => "INFO", 4 => "DEBUG", 5 => "ALL"}
	@loglevel = 3
    @rng = Random.new
    setPattern(pattern) 
    setLibrary(library)
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

  def anify(word) # If word begins with a vowel, prefix 'an', else prefix 'a'
    if (/^[aeiou]/.match(word).nil?)
      result = "a " + word
	else
      result = "an " + word
	end

	return result
  end

  def pluralise(word)
    # add s by default
    # (lf)(fe?) -> ves
	# y -> ies
	# o -> oes
    # (se?)(sh)(ch)

    # this is a pretty big problem!

    return word
  end

  def resolve_substitution(target)
    up = false
	specifier = ""

    # do we need to do post-processing?
    post = target.rindex(/\$[ap]/)

    if !post.nil? 
      specifier = target.slice(post+1, target.length - post - 1)
      target = target.slice(0, post)
    end

	# do we need to capitalise?
    if !(/^[A-Z]/.match(target).nil?)
      target = target.downcase
      up = true
    end

    # are we selecting from multiple lists?
    mult = target.index /\+/

    if mult.nil? # only one list
      return "MISSING" if @library[target].nil?
      result = parse_pattern(@library[target].sample)

    else # more than one list
      multlist = []
      listnames = []

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

	  return "MISSING" if multlist.length == 0 # no valid options found
      result = parse_pattern(multlist.sample)
    end

    # do post-processing
    if up
      result[0] = result[0].upcase
    end
    if specifier == "a"
      result = anify(result)
    end
    if specifier == "p"
      result = pluralise(result)
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

    result = options.sample
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

    if rand(100) <= chance
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
