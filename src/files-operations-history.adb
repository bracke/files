with Files.File_System;
with Files.Model.Recent;
with Files.File_System.Trash;
with Files.File_System.Permissions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Files.IO.Fs_Primitives;
with Files.Undo.Payloads;
with Files.Jobs.Context;
with Hostkit;
with Hostkit.Fs;
with Files.Operations.Support;
with Ada.Containers;
with Files.Diagnostics;
with Files.Jobs.Copy_Context;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Files.File_Identities;
with Files.Undo.Journal;
with Files.Operations.Undo_Recording;
with Files.Model.History;
with Files.Undo.History;

package body Files.Operations.History is

   use Ada.Strings.Unbounded;
   use type Files.Undo.History.Undo_Action_Kind;
   use Files.Operations.Support;
   use type Files.Undo.History.Undo_Create_Kind;

   procedure Settle_History (Model : in out Files.Model.Window_Model)
     renames Files.Operations.Undo_Recording.Settle_History;

   function Hard_Link_Snapshot (Source : String) return String is separate;

   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   function To_Set (Paths : Files.Types.String_Vectors.Vector) return Path_Sets.Set is
      Result : Path_Sets.Set;
   begin
      for Path of Paths loop
         Result.Include (To_String (Path));
      end loop;
      return Result;
   end To_Set;

   procedure Remove_Completion
     (Action : in out Files.Undo.History.Undo_Entry;
      Path : Files.Types.UString;
      Side : Files.Undo.History.History_Side)
   is separate;

   function Move_Back
     (Action : in out Files.Undo.History.Undo_Entry;
      Model : in out Files.Model.Window_Model;
      Side : Files.Undo.History.History_Side) return Boolean
   is separate;

   --  Apply Mode, or the access record Access_Text when there is one, to
   --  Action's entry Index, verified by its recorded identity.
   function Change_Recorded_Mode
     (Action      : Files.Undo.History.Undo_Entry;
      Index       : Positive;
      Mode        : Natural;
      Access_Text : String := "") return Boolean
   is separate;

   --  Apply Owner to Action's entry Index, verified by its recorded identity.
   function Change_Recorded_Ownership
     (Action : Files.Undo.History.Undo_Entry; Index : Positive; Owner : Files.Undo.Payloads.Ownership) return Boolean
   is separate;

   --  Which recorded value a permission or ownership replay applies: the
   --  one the change replaced (undo) or the one it set (redo).
   type Metadata_Side is (Before_Change, After_Change);

   --  How a metadata replay ended: every item put back, at least one that
   --  could not be, or cancelled before the end.
   type Replay_Outcome is (Replayed, Item_Failed, Stopped);

   --  Put back each entry of a permission or ownership change as Side
   --  recorded it, verified by its identity: the one replay undo and redo
   --  share. A malformed record fails its item, not the rest.
   function Replay_Metadata (Action : Files.Undo.History.Undo_Entry; Side : Metadata_Side) return Replay_Outcome
   is separate;

   --  Put Original back from the trash, verified by its identity.
   function Restore_Recorded_Trash (Original : Files.Undo.History.Replaced_Original) return Boolean is separate;

   function Apply_Reverse
     (Action : in out Files.Undo.History.Undo_Entry; Model : in out Files.Model.Window_Model)
      return Boolean
   is separate;

   function Completed_Creation_Matches
     (Action : Files.Undo.History.Undo_Entry; Index : Positive; Path : String)
      return Boolean
   is separate;

   function Apply_Forward
     (Action : in out Files.Undo.History.Undo_Entry; Model : in out Files.Model.Window_Model)
      return Boolean
   is separate;

   function Finish_Action
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Directory : String;
      Succeeded : Boolean) return Operation_Result
   is separate;

   --  Which stack Replay takes its entry from.
   type Replay_Direction is (Replay_Undo, Replay_Redo);

   --  Undo (apply in reverse) or redo (apply forward) the newest entry of
   --  one stack, then reload the directory. A fully applied entry moves to
   --  the other stack -- an undo-only one is consumed -- and a partly
   --  applied one goes back with its completed steps.
   --
   --  @param Model Window model carrying the history to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @param Direction Which stack to take the entry from.
   --  @return Structured operation result.
   function Replay
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : Replay_Direction)
      return Operation_Result
   is separate;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is (Replay (Model, Settings, Replay_Undo));

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is (Replay (Model, Settings, Replay_Redo));

   procedure Clear_Undo (Model : in out Files.Model.Window_Model) is separate;

   procedure Release_History (Model : in out Files.Model.Window_Model) is separate;

end Files.Operations.History;
