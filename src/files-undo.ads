--  Undo and redo history below the window model: the payloads an action
--  keeps (Payloads), the undo and redo stacks (History), and the on-disk
--  journal they survive restarts in (Journal). Recording an action into a
--  window's history needs the model, so it is Files.Operations.Undo_Recording.
package Files.Undo with Pure is
end Files.Undo;
