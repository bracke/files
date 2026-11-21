with Files.Copy_Context;
with Files.File_System_Types;
with Files.Paste;
with Files.Types;
with Files.Undo_History;

--  A window's paste in progress: the replace-or-skip prompt and the paste
--  being carried out. Held by the window model (Files.Model) and read and
--  set through Files.Model.Pasting; kept apart from Files.Model so the
--  model's spec need not name the copy batch and undo types they carry.
package Files.Paste_States is
   subtype UString is Files.Types.UString;

   --  The replace-or-skip prompt shown when a paste meets existing names.
   --  Every default is the closed state, as for Execution_State.
   type Conflict_State is record
      Active           : Boolean := False;
      Items            : Files.Paste.Work_Item_Vectors.Vector;
      Existing         : Files.Types.String_Vectors.Vector;
      Overrides        : Files.Paste.Item_Decision_Vectors.Vector;
      Policy           : Files.Paste.Conflict_Policy := Files.Paste.Policy_Ask;
      Mode             : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      Index            : Natural := 0;
      Apply_All        : Boolean := False;
      Clears_Clipboard : Boolean := True;
   end record;

   --  One paste (or drop) being carried out, action by action. Every field's
   --  default is the idle state, so a paste starts and ends by assigning a
   --  fresh aggregate rather than clearing each field by hand.
   type Execution_State is record
      Active                  : Boolean := False;
      Copy_Context            : Files.Copy_Context.Session;
      Actions                 : Files.Paste.Resolved_Action_Vectors.Vector;
      Cursor                  : Natural := 0;
      Done                    : Natural := 0;
      Total                   : Natural := 0;
      Mode                    : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
      Cancelled               : Boolean := False;
      Clears_Clipboard        : Boolean := True;
      Current                 : UString;
      First_Dest              : UString;
      --  Each write: the destination (From), its source (To), and the
      --  identity and tree revision it was published with, Verified when
      --  the published entry was checked.
      Written                 : Files.Undo_History.Recorded_Item_Vectors.Vector;
      --  Destinations a Replace overwrote during this paste, preserved so the
      --  undo entry can restore each to its own recorded original path.
      Replaced                : Files.Undo_History.Recorded_Original_Vectors.Vector;
   end record;
end Files.Paste_States;
