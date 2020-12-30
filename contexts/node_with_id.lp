% Demo of separate concretization for build and run dependencies

% Each node is represented by a term like:
%
% node(Package, PackageID)
%
% where the tuple (Package, PackageID uniquely identifies a node).
% The root node starts with PackageID 0
%
% Each node belongs to one or more contexts. A context is a set of 
% packages (or more precisely a sub-graph of the overall DAG) where
% each package can have at most one configuration.
%
% A term representing a context looks like:
%
% context(Name, ContextRoot, RunArchitecture, Depth)
%
% In this demo RunArchitecture represents a unique identifier for either
% the host platform or the target platform.
%
% The depth level is the number of forks from the root context that are 
% necessary to arrive at this context, and is retained only to limit recursion.

% Create the node and context for root, to kickstart the whole solve
node_in_context(
  node(Package, 0),
  context(root, node(Package, 0), TargetArchitecture, 0)
) :- root(Package), target_architecture(TargetArchitecture).

% If a node is in a context its target node must be compatible
target_node(node(Package, PackageID), ContextArchitecture)
  :- node_in_context(node(Package, PackageID), context(_, _, ContextArchitecture, _)).

% If a node is in a context, the node exists on its own as an atom
node(Package, PackageID)
  :- node_in_context(node(Package, PackageID), context(_, _, ContextArchitecture, _)).

% If a node is in a context, the context exists on its own as an atom
context(Type, Root, Architecture, Depth) :- node_in_context(_, context(Type, Root, Architecture, Depth)).

% Limit depth level to avoid recursive explosion of contexts
:- context(root , _, _, Depth), Depth != 0.
:- context(run  , _, _, Depth), Depth > 1.
:- context(build, _, _, Depth), Depth > 2.

% Target and Host architecture are always to be intended as
% archspec's architecture family. This permits to emit facts
% prior to the solve even outside of this synthetic example.

% The root context always run on the target architecture
:- target_architecture(Arch1), context(root, _, Arch2, _), Arch1 != Arch2.

% Each build context always run on the host architecture
:- host_architecture(Arch1), context(build, _, Arch2, _), Arch1 != Arch2.

% We are cross-compiling if a the target architecture is different from the host
cross_compiling :- target_architecture(T), host_architecture(H), T != H.

% Whether a node is on host or on target
node_on_host(node(P, ID))
  :- node(P, ID), host_architecture(T), target_node(node(P, ID), T).

node_on_target(node(P, ID)) 
  :- node(P, ID), target_architecture(T), target_node(node(P, ID), T).

% Limit the number of possible duplicate nodes to 3
node(Package, 0) :- root(Package).
{ node(Package, 0..2) } :- declared_dependency(_, Package, _).

% Can't have two different target for the same node
:- target_node(Node, Arch1), target_node(Node, Arch2), Arch1 != Arch2.

%%%%
% Rules to determine whether a node is in a process context, and construct the edges
%%%%

% Deduction from edge_info
node_in_context(Node, Context) :- edge_info(_, node_in_context(Node, Context), _).
depends_on(ParentNode, DependencyNode, DependencyType) 
  :- edge_info(ParentNode, node_in_context(DependencyNode, _), DependencyType).

% For each link dependency we inherit the parent context
1 { edge_info(
      node(Parent, ParentID),
      node_in_context(node(Dependency, DependencyID), ParentContext),
      link
    ) : node(Dependency, DependencyID) } 1
  :- declared_dependency(Parent, Dependency, link),
     node_in_context(node(Parent, ParentID), ParentContext).


% Build dependencies can be forked from the root context at depth 0, or from
% a run context at depth 1 (root->run->build).
fork_build_context(node(Parent, ParentID), Dependency, 1) 
  :- declared_dependency(Parent, Dependency, build),
     node_in_context(node(Parent, ParentID), context(root, _, _, 0)).

fork_build_context(node(Parent, ParentID), Dependency, 2)
  :- declared_dependency(Parent, Dependency, build),
     node_in_context(node(Parent, ParentID), context(run, _, _, 1)).

1 { edge_info(
      node(Parent, ParentID),
      node_in_context(node(Dependency, DependencyID), context(build, node(Dependency, DependencyID), HostArchitecture, Depth)),
      build
    ) : node(Dependency, DependencyID) } 1
  :- declared_dependency(Parent, Dependency, build),
     fork_build_context(node(Parent, ParentID), Dependency, Depth),
     host_architecture(HostArchitecture),
     Depth = 1..2.

% Run dependencies can only be forked from root at depth 0
fork_run_context(node(Parent, ParentID), Dependency, 1)
  :- declared_dependency(Parent, Dependency, run),
     node_in_context(node(Parent, ParentID), context(root, _, _, 0)).

1 { edge_info(
      node(Parent, ParentID),
      node_in_context(node(Dependency, DependencyID), context(run, node(Dependency, DependencyID), TargetArchitecture, Depth)),
      run
    ) : node(Dependency, DependencyID) } 1
  :- declared_dependency(Parent, Dependency, run),
     fork_run_context(node(Parent, ParentID), Dependency, Depth),
     target_architecture(TargetArchitecture),
     Depth = 1.

% In all other cases inherit the context from the parent
1 { edge_info(
      node(Parent, ParentID),
      node_in_context(node(Dependency, DependencyID), ParentContext),
      DependencyType
   ) : node(Dependency, DependencyID) 
} 1
  :- declared_dependency(Parent, Dependency, DependencyType),
     node_in_context(node(Parent, ParentID), ParentContext),
     not fork_build_context(node(Parent, ParentID), Dependency, _),
     not fork_run_context(node(Parent, ParentID), Dependency, _).

% Minimize the number of duplicate nodes required to satisfy all the contexts
% Note that here it's crucial that ID numbering starts from 0, since it means 
% that the first node does not affect the minimization result. Said otherwise, 
% starting from 0 ensure that we are minimizing the number of duplicate nodes 
% without minimizing the total number of different nodes. 
#minimize { ID,Package : node(Package, ID) }.

% Change the values below to be the same or to be different to check how nodes split
host_architecture(x86_64).
target_architecture(aarch64).

% add arch, compiler, process, etc. to nodes
% what's the node identifier?
% how do we establish that a node is "same"? just optimize for all attrs same?
% Or restrict the attrs that can split a node?

% Rules for package versions
1 { version(node(Package, ID), Version, Weight) : 
    version_declared(Package, Version, Weight) } 1
  :- node(Package, ID).

#minimize { Weight@10,Package,ID,Version : version(node(Package, ID), Version, Weight) }.

root("n1").

declared_dependency("n1",  "n2", build).
declared_dependency("n2",  "n3", build).
declared_dependency("n2",  "n4", link).

declared_dependency("n1",  "n5", build).
declared_dependency("n1",  "n5", link).
declared_dependency("n5",  "n6", build).
declared_dependency("n5",  "n7", link).
declared_dependency("n6",  "n8", run).
declared_dependency("n7",  "n8", run).

version_declared("n1", "2.0", 1).
version_declared("n1", "1.0", 2).

version_declared("n2", "2.0", 1).
version_declared("n2", "1.0", 2).

version_declared("n3", "2.0", 1).
version_declared("n3", "1.0", 2).

version_declared("n4", "2.0", 1).
version_declared("n4", "1.0", 2).

version_declared("n5", "2.0", 1).
version_declared("n5", "1.0", 2).

version_declared("n6", "2.0", 1).
version_declared("n6", "1.0", 2).

version_declared("n7", "2.0", 1).
version_declared("n7", "1.0", 2).

version_declared("n8", "2.0", 1).
version_declared("n8", "1.0", 2).

%#show declared_dependency/"2.
%#show version/4.

%#show node/2.
%#show depends_on/3.
#show node_in_context/2.
%#show target_node/2.
%#show context/4.