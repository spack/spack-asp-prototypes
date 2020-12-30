% Demo of separate build dependencies

%
% Each node is uniquely identified by:
%
% node(Package, ParentContext, PackageContext)
%
% where ParentContext is the context that gave origin 
% to PackageContext.
%
% In this demo we try to minimize the number of contexts.
% As such the cross-compilation case has more contexts 
% than the case where target and host architecture coincide.
%

% Each root R has its own process called (root, R, target)
node(R, context(root, R, TargetArchitecture), forkable) 
  :- root(R), target_architecture(TargetArchitecture).

% if something is a process of a node, it is a process
context(Type, Root, Where) :- node(_, context(Type, Root, Where), _).

% Link dependencies are in the same process as parent
node(B, ContextA, ForkableState) :- 
  declared_dependency(A, B, link), 
  node(A, ContextA, ForkableState).

node(B, Context, unforkable) :- 
  declared_dependency(A, B, _), 
  node(A, Context, unforkable).

% The root context spawns build and run contexts 
1 { node(B, context(root,  Root, HostArchitecture), unforkable); 
    node(B, context(build, B,    HostArchitecture),   unforkable) } 1
  :- declared_dependency(A, B, build), 
     node(A, context(root, Root, TargetArchitecture), forkable),
     host_architecture(HostArchitecture).

:- target_architecture(Arch1), context(root, _, Arch2), Arch1 != Arch2.
:- host_architecture(Arch1),   context(build, _, Arch2), Arch1 != Arch2.

1 { node(B, context(root, Root, TargetArchitecture), unforkable);
    node(B, context(run , B,    TargetArchitecture), unforkable) } 1
  :- declared_dependency(A, B, run), 
     node(A, context(root, Root, TargetArchitecture), forkable).

% A run context may only spawn new build contexts
1 { node(B, context(run,   Root, HostArchitecture), unforkable);
    node(B, context(build, B,    HostArchitecture), unforkable)} 1
  :- declared_dependency(A, B, build), 
     node(A, context(run, Root, TargetArchitecture), forkable), 
     host_architecture(HostArchitecture),
     target_architecture(TargetArchitecture),
     HostArchitecture == TargetArchitecture.

node(B, context(build, B,    HostArchitecture), unforkable)
  :- declared_dependency(A, B, build), 
     node(A, context(run, Root, TargetArchitecture), forkable), 
     host_architecture(HostArchitecture),
     target_architecture(TargetArchitecture),
     HostArchitecture != TargetArchitecture.

node(B, context(run, ContextRoot, Target), forkable) :- 
  declared_dependency(A, B, run), 
  node(A, context(run, ContextRoot, Target), forkable).

% Construct a proper dependency tree, accounting for the process space
depends_on((A, ContextA), (B, ContextB), Type) 
  :- declared_dependency(A, B, Type), node(A, ContextA, _), node(B, ContextB, _).

host_architecture(x86_64).
target_architecture(aarch64).

% add arch, compiler, process, etc. to nodes
% what's the node identifier?
% how do we establish that a node is "same"? just optimize for all attrs same?
% Or restrict the attrs that can split a node?

% Rules for package versions
1 { version(Package, Context, Version, Weight) : 
    version_declared(Package, Version, Weight), 
    node(Package, Context, _) } 1
 :- node(Package, Context, _).

% Minimize the number of contexts
#minimize { 1@5,Type,Root,Where : context(Type, Root, Where) }.

#minimize { Weight@10,Package,Version : version(Package,Process, Version, Weight) }.

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

:- version("n8", (run, "n8", target), "2.0", _).

%#show declared_dependency/"2.
%#show depends_on/3.
%#show version/4.
%#show node/3.
#show context/3.