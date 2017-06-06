using Compat

"""
    Node(Vector{Int}, Vector{Int}) <: AbstractNode

A node of phylogenetic tree
"""
type Node <: AbstractNode
    inbound::Int
    outbounds::Vector{Int}

    function Node(inbound::Int, outbounds::Vector{Int})
        inbound >= 0 ||
            error("Node must have positive inbound branch number")
        all(outbounds .> 0) ||
            error("Node must have positive outbound branch numbers")
        new(inbound, outbounds)
    end
end

function Node()
    return Node(0, Int[])
end

function _hasinbound(node::Node)
    return node.inbound != 0
end

function _outdegree(node::Node)
    return length(node.outbounds)
end

function _hasoutboundspace(::Node)
    return true
end

function _getinbound(node::Node)
    _hasinbound(node) || error("Node has no inbound connection")
    return node.inbound
end

function _setinbound!(node::Node, inbound::Int)
    !_hasinbound(node) || error("Node already has an inbound connection")
    node.inbound = inbound
end

function _deleteinbound!(node::Node, inbound::Int)
    node.inbound == inbound ||
        error("Node does not have inbound connection from branch $inbound")
    node.inbound = inbound
end

function _getoutbounds(node::Node)
    return node.outbounds
end

function _addoutbound!(node::Node, outbound::Int)
    outbound ∉ node.outbounds ||
        error("Node already has outbound connection to $outbound")
    _hasoutboundspace(node) ||
        error("Node cannot have any more outbound connections")
    push!(node.outbounds, outbound)
end

function _deleteoutbound!(node::Node, outbound::Int)
    outbound ∈ node.outbounds ? Compat.Iterators.filter!(i -> i != outbound, node.outbound) :
        error("Node does not have outbound connection from branch $outbound")
end

"""
    BinaryNode{T}(AbstractVector{T}, AbstractVector{T}) <: AbstractNode

A node of strict binary phylogenetic tree
"""
type BinaryNode{T} <: AbstractNode
    inbound::Nullable{T}
    outbounds::Tuple{Nullable{T}, Nullable{T}}

    function (::Type{BinaryNode{T}}){T}(inbound::AbstractVector{T} = T[],
                                        outbounds::AbstractVector{T} = T[])
        length(inbound) <= 1 ||
            error("At most one inbound connection to BinaryNode")
        n_in = length(inbound) == 0 ? Nullable{T}() :
            Nullable(inbound[1])
        length(outbounds) <= 2 ||
            error("At most two outbound connections from BinaryNode")
        n_out = length(outbounds) == 0 ? (Nullable{T}(), Nullable{T}()) :
            (length(outbounds) == 1 ? (Nullable(outbounds[1]), Nullable{T}()) :
             (Nullable(outbounds[1]), Nullable(outbounds[2])))
        new{T}(n_in, n_out)
    end
end

function _hasinbound(node::BinaryNode)
    return !isnull(node.inbound)
end

function _outdegree(node::BinaryNode)
    return (isnull(node.outbounds[1]) ? 0 : 1) +
        (isnull(node.outbounds[2]) ? 0 : 1)
end

function _hasoutboundspace(node::BinaryNode)
    return _outdegree(node) < 2
end

function _getinbound(node::BinaryNode)
    _hasinbound(node) ||
        error("Node has no inbound connection")
    return get(node.inbound)
end

function _setinbound!{T}(node::BinaryNode{T}, inbound::T)
    !_hasinbound(node) ||
        error("BinaryNode already has an inbound connection")
    node.inbound = inbound
end

function _deleteinbound!{T}(node::BinaryNode{T}, inbound::T)
    _hasinbound(node) ||
        error("Node has no inbound connection")
    get(node.inbound) != inbound ||
        error("BinaryNode has no inbound connection from branch $inbound")
    node.inbound = Nullable{T}()
end

function _getoutbounds{T}(node::BinaryNode{T})
    return isnull(node.outbounds[1]) ?
        (isnull(node.outbounds[2]) ? T[] : [get(node.outbounds[2])]) :
        (isnull(node.outbounds[2]) ? [get(node.outbounds[1])] :
         [get(node.outbounds[1]), get(node.outbounds[2])])
end

function _addoutbound!{T}(node::BinaryNode{T}, outbound::T)
    isnull(node.outbounds[1]) ?
        node.outbounds = (Nullable(outbound), node.outbounds[2]) :
        (isnull(node.outbounds[2]) ?
         node.outbounds = (node.outbounds[1], Nullable(outbound)) :
         error("BinaryNode already has two outbound connections"))
end

function _deleteoutbound!{T}(node::BinaryNode{T}, outbound::T)
    node.outbounds[1] == outbound ?
        node.outbounds = (node.outbounds[2], Nullable{T}()) :
        (node.outbounds[2] == outbound ?
         node.outbounds = (node.outbounds[1], Nullable{T}()) :
         error("BinaryNode does not have outbound connection to branch $outbound"))
end

"""
    Branch

    A directed branch connecting two AbstractNodes of phylogenetic tree
"""
type Branch{T}
    source::T
    target::T
    length::Float64

    function (::Type{Branch{T}}){T}(source::T, target::T, length::Float64)
        length >= 0.0 || isnan(length) ||
            error("Branch length must be positive or NaN (no recorded length)")
        new{T}(source, target, length)
    end
end

Branch{T}(source::T, target::T, length::Float64) =
    Branch{T}(source, target, length)

const SimpleBranch = Branch{Int}

_getsource(branch::Branch) = branch.source
_gettarget(branch::Branch) = branch.target
_setsource!{T}(branch::Branch{T}, source::T) = branch.source = source
_settarget!{T}(branch::Branch{T}, target::T) = branch.target = target
_getlength(branch::Branch) = branch.length

function checkbranch(id::Int, branch::Branch, tree::AbstractTree)
    return id > 0 &&
        getsource(branch) != gettarget(branch) &&
        !haskey(getbranches(tree), id) &&
        haskey(getnodes(tree), getsource(branch)) &&
        haskey(getnodes(tree), gettarget(branch)) &&
        !hasinbound(getnodes(tree)[gettarget(branch)]) &&
        outboundspace(getnodes(tree)[getsource(branch)])
end


type LeafInfo <: AbstractInfo
    height::Nullable{Float64}
end

_hasheight(li::LeafInfo) = !isnull(li.height)
_getheight(li::LeafInfo) = get(li.height)
_setheight!(li::LeafInfo, height::Float64) = li.height = height

LeafInfo() = LeafInfo(Nullable{Float64}())
