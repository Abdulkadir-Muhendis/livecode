'module' types

'use'
    support

'export'
    MODULE MODULELIST
    IMPORT
    DEFINITION SIGNATURE ACCESS
    TYPE FIELD FIELDLIST
    PARAMETER MODE PARAMETERLIST
    STATEMENT
    EXPRESSION EXPRESSIONLIST
    SYNTAX SYNTAXCLASS SYNTAXASSOC SYNTAXCONSTANT SYNTAXCONSTANTLIST SYNTAXMETHOD SYNTAXMETHODLIST SYNTAXTERM
    ID IDLIST
    MEANING
    SYNTAXMARKINFO SYNTAXMARKTYPE
    NAME DOUBLE

--------------------------------------------------------------------------------

'type' MODULELIST
    modulelist(Head: MODULE, Tail: MODULELIST)
    nil

'type' MODULE
    module(Position: POS, Name: ID, Imports: IMPORT, Definitions: DEFINITION)

'type' IMPORT
    sequence(Left: IMPORT, Right: IMPORT)
    import(Position: POS, Name: ID)
    nil
    
'type' DEFINITION
    sequence(Left: DEFINITION, Right: DEFINITION)
    type(Position: POS, Access: ACCESS, Name: ID, Type: TYPE)
    constant(Position: POS, Access: ACCESS, Name: ID, Value: EXPRESSION)
    variable(Position: POS, Access: ACCESS, Name: ID, Type: TYPE)
    handler(Position: POS, Access: ACCESS, Name: ID, Signature: SIGNATURE, Definitions: DEFINITION, Body: STATEMENT)
    foreignhandler(Position: POS, Access: ACCESS, Name: ID, Signature: SIGNATURE, Binding: STRING)
    property(Position: POS, Access: ACCESS, Name: ID)
    event(Position: POS, Access: ACCESS, Name: ID)
    syntax(Position: POS, Access: ACCESS, Name: ID, Class: SYNTAXCLASS, Syntax: SYNTAX, Methods: SYNTAXMETHODLIST)
    nil

'type' SIGNATURE
    signature(Parameters: PARAMETERLIST, ReturnType: TYPE)

'type' ACCESS
    inferred
    public
    protected
    private

'type' TYPE
    named(Position: POS, Name: ID)
    opaque(Position: POS, Base: TYPE, Fields: FIELDLIST)
    record(Position: POS, Base: TYPE, Fields: FIELDLIST)
    enum(Position: POS, Base: TYPE, Fields: FIELDLIST)
    handler(Position: POS, Signature: SIGNATURE)
    pointer(Position: POS)
    bool(Position: POS)
    int(Position: POS)
    uint(Position: POS)
    float(Position: POS)
    double(Position: POS)
    any(Position: POS)
    boolean(Position: POS)
    integer(Position: POS)
    real(Position: POS)
    number(Position: POS)
    string(Position: POS)
    data(Position: POS)
    array(Position: POS)
    list(Position: POS)
    undefined(Position: POS)
    nil

'type' FIELDLIST
    fieldlist(Head: FIELD, Tail: FIELDLIST)
    nil
    
'type' FIELD
    action(Position: POS, Name: ID, Handler: ID)
    slot(Position: POS, Name: ID, Type: TYPE)
    element(Position: POS, Name: ID)
    nil

'type' PARAMETERLIST
    parameterlist(Head: PARAMETER, Tail: PARAMETERLIST)
    nil
    
'type' PARAMETER
    parameter(Position: POS, Mode: MODE, Name: ID, Type: TYPE)
    
'type' MODE
    in
    out
    inout

'type' STATEMENT
    sequence(Left: STATEMENT, Right: STATEMENT)
    variable(Position: POS, Name: ID, Type: TYPE)
    if(Position: POS, Condition: EXPRESSION, Consequent: STATEMENT, Alternate: STATEMENT)
    repeatforever(Position: POS, Body: STATEMENT)
    repeatcounted(Position: POS, Count: EXPRESSION, Body: STATEMENT)
    repeatwhile(Position: POS, Condition: EXPRESSION, Body: STATEMENT)
    repeatuntil(Position: POS, Condition: EXPRESSION, Body: STATEMENT)
    repeatupto(Position: POS, Slot: ID, Start: EXPRESSION, Finish: EXPRESSION, Step: EXPRESSION, Body: STATEMENT)
    repeatdownto(Position: POS, Slot: ID, Start: EXPRESSION, Finish: EXPRESSION, Step: EXPRESSION, Body: STATEMENT)
    repeatforeach(Position: POS, Iterator: EXPRESSION, Slot: ID, Container: EXPRESSION, Body: STATEMENT)
    nextrepeat(Position: POS)
    exitrepeat(Position: POS)
    return(Position: POS, Value: EXPRESSION)
    call(Position: POS, Handler: ID, Arguments: EXPRESSIONLIST)
    invoke(Position: POS, Method: INT, Arguments: EXPRESSIONLIST)
    nil
    
'type' EXPRESSIONLIST
    expressionlist(Head: EXPRESSION, Tail: EXPRESSIONLIST)
    nil
    
'type' EXPRESSION
    null(Position: POS)
    true(Position: POS)
    false(Position: POS)
    integer(Position: POS, Value: INT)
    real(Position: POS, Value: DOUBLE)
    string(Position: POS, Value: STRING)
    slot(Position: POS, Name: ID)
    as(Position: POS, Value: EXPRESSION, Type: TYPE)
    list(Position: POS, List: EXPRESSIONLIST)
    call(Position: POS, Handler: ID, Arguments: EXPRESSIONLIST)
    invoke(Position: POS, Method: INT, Arguments: EXPRESSIONLIST)
    nil

'type' SYNTAX
    concatenate(Position: POS, Left: SYNTAX, Right: SYNTAX)
    alternate(Position: POS, Left: SYNTAX, Right: SYNTAX)
    repeat(Position: POS, Element: SYNTAX)
    list(Position: POS, Element: SYNTAX, Delimiter: SYNTAX)
    optional(Position: POS, Operand: SYNTAX)
    keyword(Position: POS, Value: STRING)
    markedrule(Position: POS, Variable: ID, Name: ID)
    rule(Position: POS, Name: ID)
    mark(Position: POS, Variable: ID, Value: SYNTAXCONSTANT)

'type' SYNTAXCLASS
    phrase
    statement
    iterator
    expression
    prefix(Precedence: INT)
    postfix(Precedence: INT)
    binary(Assoc: SYNTAXASSOC, Precedence: INT)

'type' SYNTAXASSOC
    left
    right
    neutral

'type' SYNTAXCONSTANTLIST
    constantlist(Head: SYNTAXCONSTANT, Tail: SYNTAXCONSTANTLIST)
    nil

'type' SYNTAXCONSTANT
    undefined(Position: POS)
    true(Position: POS)
    false(Position: POS)
    integer(Position: POS, Value: INT)
    string(Position: POS, Value: STRING)
    variable(Position: POS, Name: ID)
    indexedvariable(Position: POS, Name: ID, Index: INT)

'type' SYNTAXMETHODLIST
    methodlist(Head: SYNTAXMETHOD, Tail: SYNTAXMETHODLIST)
    nil
    
'type' SYNTAXMETHOD
    method(Position: POS, Name: ID, Arguments: SYNTAXCONSTANTLIST)

'type' SYNTAXTERM
    error
    mark
    expression
    keyword
    mixed

'type' IDLIST
    idlist(Head: ID, Tail: IDLIST)
    nil

'type' MEANING
    definingid(Id: ID)
    module
    type
    constant
    variable
    handler(Signature: SIGNATURE)
    property
    event
    parameter
    syntaxrule(Class: SYNTAXCLASS, Syntax: SYNTAX)
    syntaxmark(Info: SYNTAXMARKINFO)
    syntaxexpressionrule
    syntaxexpressionlistrule
    syntaxoutputmark
    syntaxinputmark
    syntaxcontextmark
    syntaxcontainermark
    syntaxiteratormark
    error
    nil

'type' SYNTAXMARKTYPE
    error
    boolean
    integer
    string
    phrase
    expression

'table' ID(Position: POS, Name: NAME, Meaning: MEANING)

'table' SYNTAXMARKINFO(Index: INT, Type: SYNTAXMARKTYPE)

'table' TYPEID(Position: POS)
'table' SYNTAXID(Position: POS)

--------------------------------------------------------------------------------

'type' NAME
'type' DOUBLE

--------------------------------------------------------------------------------
