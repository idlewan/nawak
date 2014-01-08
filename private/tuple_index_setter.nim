import macros
import jesterpatterns

macro inject_tuple_setter_by_index*(index_var, tuple_to_set, new_val: expr,
                                    path: string): stmt {.immediate, closure.} =
    # count the number of fields in the url_params tuple
    var fields_len = 0
    var path_str = $toStrLit(path)
    path_str = path_str[1 .. path_str.len - 2]
    var pattern = parsePattern(path_str)
    for node in pattern:
        case node.typ
        of TNodeField:
            inc(fields_len)
        else:
            discard

    if fields_len == 0:
        result = newEmptyNode()
        return

    result = newNimNode(nnkCaseStmt)
    result.add(newIdentNode($toStrLit(index_var)))

    for i in 0..fields_len-1:
        if i == fields_len-1:  # the last position will be the default case
            break
        var node = newNimNode(nnkOfBranch)
        node.add newIntLitNode(i)

        var bracket_expr = newNimNode(nnkBracketExpr)
        bracket_expr.add newIdentNode($toStrLit(tuple_to_set))
        bracket_expr.add newIntLitNode(i)

        node.add(newStmtList(
            newAssignment( bracket_expr, newIdentNode($toStrLit(new_val)) )
        ))

        result.add node
    
    # default case (the else)
    result.add(newNimNode(nnkElse).add(
        newAssignment(
            newNimNode(nnkBracketExpr).add(
                newIdentNode($toStrLit(tuple_to_set))
            ).add(
                newIntLitNode(fields_len-1)
            ),
            newIdentNode($toStrLit(new_val))
        )
    ))
