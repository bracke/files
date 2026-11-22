with Files.Model;
with Files.Settings;

--  Undo and redo: replaying a recorded action backwards or forwards, and
--  releasing the history.
package Files.Operations.History is

   --  Undo the most recently recorded reversible action: pop the top undo
   --  entry, apply its reverse, push it onto the redo stack (unless it is
   --  undo-only), then reload the directory. Undo history is multi-level, so
   --  repeated calls unwind actions in last-in-first-out order.
   --
   --  @param Model Window model carrying the undo history to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result; failed when nothing is available or
   --          an inverse step could not be applied.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  Redo the most recently undone action: pop the top redo entry, apply it
   --  forward, push it back onto the undo stack, then reload the directory.
   --
   --  @param Model Window model carrying the redo history to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result; failed when nothing is available or
   --          a forward step could not be applied.
   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  End the history with its window: originals a paste replaced, kept in a
   --  hidden recovery folder only so Undo could put them back, go to the
   --  system trash under their own names instead of staying hidden there.
   --
   --  @param Model Model whose history ends.
   procedure Release_History (Model : in out Files.Model.Window_Model);

end Files.Operations.History;
