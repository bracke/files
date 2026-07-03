--  Renderer-agnostic GUI layer.
--
--  Packages under Files.Gui hold the generic, domain-free draw model and the
--  rendering backends that consume it. Nothing in this subtree depends on the
--  file-manager domain packages (model, settings, commands, file system, ...),
--  so the compiler enforces the boundary between presentation primitives and
--  application logic.
package Files.Gui is
end Files.Gui;
