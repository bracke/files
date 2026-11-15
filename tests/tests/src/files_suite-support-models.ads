with Files.Operation_Results;
with Files.Extra_Info;
with Files.Items;
with Files.Commands;
with Files.Events;
with Files.Model;
with Files.Rendering;
with Files.Settings;
with Guikit.Input;
with Files.Types;

--  Drivers for the window model: sample items and models, running a command,
--  finishing a paste or the folder-size walks as the frame loop would, a
--  simulated click, and the undo records tests build.
package Files_Suite.Support.Models is

   --  Run a command through the controller's command entry
   --  (Files.Controller.Execute_Non_Settings_Command) with default settings, for a
   --  test that checks the command's effect on the model and not its result.
   --
   --  @param Id Command to run.
   --  @param Model Window model the command acts on.
   procedure Run_Command
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model);

   --  Advance Model's paste execution one item at a time, as the frame loop
   --  does, until it ends, and assert it ended within the (scaled) poll
   --  limit. It is advanced at least once.
   --
   --  @param Model Window model whose paste execution to finish.
   --  @param Settings Settings the execution runs with.
   --  @return The result of the last advance.
   function Finish_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operation_Results.Operation_Result;

   --  Drive every queued background folder-size walk of Model to completion,
   --  publishing each result as the frame loop's Poll_Window_Workers would,
   --  and assert they finished within the (scaled) poll limit.
   --
   --  @param Model Window model whose folder scans to drain.
   procedure Drain_Folder_Sizes (Model : in out Files.Model.Window_Model);

   --  Translate a simulated click against a snapshot into an input action.
   --
   --  @param Snapshot View snapshot the click is tested against.
   --  @param X Click X coordinate in pixels.
   --  @param Y Click Y coordinate in pixels.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Activate True for a double-click/activation.
   --  @param Modifiers Active keyboard modifiers.
   --  @param Line_Height Text line height in pixels.
   --  @return The resulting input action.
   function Click_Action
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive := 20)
      return Files.Events.Input_Action;

   --  Build a sample set of directory items for tests.
   --
   --  @return A vector of sample directory items.
   function Sample_Items return Files.Items.Item_Vectors.Vector;

   --  Build a sample window model populated with sample items.
   --
   --  @return A sample window model.
   function Sample_Model return Files.Model.Window_Model;

   --  Select the item with the given name in the model.
   --
   --  @param Model Model whose selection is updated.
   --  @param Name Name of the item to select.
   procedure Select_Name (Model : in out Files.Model.Window_Model; Name : String);

   --  An extra info written compactly for an expectation ("text.lines_encoding|1|ascii"):
   --  the kind, then its fields. Only ever written, never read back.
   --
   --  @param Extra The extra info.
   --  @return Its description, "" for none.
   function Describe (Extra : Files.Extra_Info.Info) return String;

   --  A paste execution over Count numbered files, armed and not yet
   --  advanced: the root reset, files f1.txt .. in Src_Dir (holding S1 ..),
   --  Model opened on the empty Dest_Dir, and a copy of each into it.
   --
   --  @param Model Window model to open on Dest_Dir.
   --  @param Settings Settings the destination is listed with.
   --  @param Src_Dir Directory the sources are written to.
   --  @param Dest_Dir Directory they are copied into.
   --  @param Count Number of files.
   procedure Arm_Numbered_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Src_Dir  : String;
      Dest_Dir : String;
      Count    : Positive);

   --  An action's items from its path lists, for a fixture recorded through
   --  Files.Undo_Recording: item Index has From (Index) and the Index-th of
   --  each other list, or "" past its end.
   --
   --  @param From Current locations.
   --  @param To Old locations or values.
   --  @param Forward Redo sources or new values.
   --  @param Identities Identities as published.
   --  @param Tree_Revisions Tree revisions as published.
   --  @param Provenance How the record knows each item: Captured reads its
   --    identity afresh, ignoring Identities and Tree_Revisions.
   --  @return The items, in From's order.
   function Undo_Items
     (From           : Files.Types.String_Vectors.Vector;
      To             : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Forward        : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Identities     : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector := Files.Types.String_Vectors.Empty_Vector;
      Provenance     : Files.Model.Item_Provenance := Files.Model.Captured)
      return Files.Model.Recorded_Item_Vectors.Vector;

   --  Originals a replace preserved at Trash, their identities and targets
   --  to be captured.
   --
   --  @param Trash Where each is preserved.
   --  @return The originals, in order.
   function Replaced_Originals
     (Trash : Files.Types.String_Vectors.Vector) return Files.Model.Recorded_Original_Vectors.Vector;

end Files_Suite.Support.Models;
