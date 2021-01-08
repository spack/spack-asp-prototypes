% DEMO: conditional dependencies with multiple nodes in the DAG from the same package
%
% Demo program to check how to deal with conditional statements stemming from 
% package directives that involve dependencies, e.g.:
%
% depends_on('openssl', when='@1.2.11 ^cmake@3.18.1')
%
% This type of directives results in facts like:
%
% condition(16).
% condition_requirement(16,node,"zlib").
% condition_requirement(16,node,"cmake").
% condition_requirement(16,version_satisfies,"zlib", "1.2.11").
% condition_requirement(16,version_satisfies,"cmake","3.18.1").
% dependency_condition(16,"zlib","openssl").
% dependency_type(16,"build").
% dependency_type(16,"link").
%
% being emitted. These facts are associated with a package and are the same for each
% node in the DAG representing a different configuration of the package.
%
% This demo shows how to structure a logic program in a way that allows the 
% generation of grounded rules that try different configurations for each package
% involved in a directive, so to keep track of what depends on what in case of 
% multiple nodes instances from the same package.
%
% The point is to be able to associate each constraint that is required to 
% trigger a dependency or a conflict with the right node. 
%
% A node is identified by a package name and an integer ID:
%
% node(Package, PackageID)

% Grounded rule we are seeking:
%
% condition_holds(16, node(zlib, 0))
%   :- node(zlib, 0);
%      version_satisfies(node("zlib", 0), "1.2.11");
%      transitive_condition_holds(16, node("zlib", 0), node("cmake", _))
%      condition(16).

% Maximum number of nodes in the DAG for each package
#const max = 2.

condition_holds(ID, node(RootPackage, Idx))
  :- Idx = 0..max;
     node(RootPackage, Idx);
     condition_root(ID, RootPackage);
     % In concretize.lp this needs to be generalized to:
     % attr(Name, RootPackage, Idx, A2) : condition_requirement(ID, Name, RootPackage, A2);
     version_satisfies(node(Package, Idx), Version) : condition_requirement(ID, version_satisfies, RootPackage, Version);
     transitive_condition_holds(ID, node(RootPackage, Idx), node(Package, _)) : condition_requirement(ID, version_satisfies, Package, Version), Package != RootPackage;
     condition(ID).

transitive_condition_holds(ID, node(RootPackage, RootID), node(Dependency, DependencyID))
  :- RootID = 0..max; DependencyID = 0..max; Dependency != RootPackage;
     node(RootPackage, RootID); node(Dependency, DependencyID);
     path(node(RootPackage, RootID), node(Dependency, DependencyID));
     version_satisfies(node(Dependency, DependencyID), Version) : condition_requirement(ID, version_satisfies, Dependency, Version);
     condition(ID).


condition(16).
condition_root(16, "zlib").

{ node("zlib", 0..2) }.
condition_requirement(16, node, "zlib").
condition_requirement(16, version_satisfies, "zlib", "1.2.11").
version_satisfies(node("zlib", 0), "1.2.11").

{ node("cmake", 0..max) }.
condition_requirement(16, version_satisfies, "cmake", "3.18.1").
version_satisfies(node("cmake", 1), "3.18.1").
version_satisfies(node("cmake", 0), "3.16.1").

path(node("zlib", 0), node("cmake", 1)).

#maximize { ID,RootNode : condition_holds(ID, RootNode) }.
