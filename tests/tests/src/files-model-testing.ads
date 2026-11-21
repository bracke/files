with Files.History_Journal;
with Files.Items;
with Files.Types;
with Files.Undo_History;

--  Test-only queries of Files.Model: state the suite inspects and the program
--  never asks for, kept out of the program.
package Files.Model.Testing is

   --  @param Model Window whose measurement to inspect.
   --  @return True when its size helper is active.
   function Folder_Scan_Is_Active (Model : Window_Model) return Boolean;
   --  @param Model Window whose measurement to inspect.
   --  @return Active measurement path, or empty when idle.
   function Folder_Scan_Target (Model : Window_Model) return String;
   --  Return the number of active inline rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Count of rename fields (zero when rename is inactive).
   function Rename_Field_Count
     (Model : Window_Model)
      return Natural;
   --  Return the rename state for the item shown at Visible_Index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible row index.
   --  @param Active Set True when that row has an active rename field.
   --  @param Value Field text (empty when inactive).
   --  @param Cursor Field caret byte offset (zero when inactive).
   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural);
   --  Return whether the current selection is the temporary create-file item.
   --
   --  @param Model Model to inspect.
   --  @return True when the pending create-file item is selected.
   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean;
   --  Return the visible grid column count used by vertical selection movement.
   --
   --  @param Model Model to inspect.
   --  @return Number of visible item columns used as the vertical movement stride.
   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive;
   --  Return the kind of the top undo entry.
   --
   --  @param Model Model to inspect.
   --  @return Undo_None when the undo stack is empty.
   function Undo_Kind_Of
     (Model : Window_Model)
      return Files.Undo_History.Undo_Action_Kind;
   --  Return the top undo entry's "to" (restore-target) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of restore targets, parallel to Undo_From_Paths.
   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;
   --  The item at Index in the model's own order, visible or not.
   --
   --  @param Model Model to inspect.
   --  @param Index Item index, 1 .. Item_Count.
   --  @return The item.
   function Item_At (Model : Window_Model; Index : Positive) return Files.Items.Directory_Item;

   --  Cache a recursive folder-size measurement for a directory path.
   --
   --  The cache holds one measurement at a time, keyed by Path, so a repeated
   --  selection of the same directory reuses it instead of walking again.
   --
   --  @param Model Model to update.
   --  @param Path Directory the measurement describes.
   --  @param Value Recursive size totals for Path.
   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System_Types.Directory_Size_Result);
   --  Clear the destination-picker sub-mode and its captured sources.
   --
   --  @param Model Model to update.
   procedure Clear_Tree_Pick
     (Model : in out Window_Model);
   --  Return whether one input-owning overlay is open.
   --
   --  @param Model Model to inspect.
   --  @param Overlay The overlay to ask about.
   --  @return True while Overlay is open (or, for a paste, active).
   function Overlay_Is_Open
     (Model   : Window_Model;
      Overlay : Input_Overlay)
      return Boolean;
   --  Cancel temporary create-file state.
   --
   --  @param Model Model to update.
   procedure Cancel_Create_File
     (Model : in out Window_Model);

   --  The armed paste's write actions completed so far (the program reads
   --  them through Files.Model.Jobs.Foreground_Progress_Of).
   --
   --  @param Model Model to inspect.
   --  @return Count of items already copied or moved.
   function Paste_Execution_Done (Model : Window_Model) return Natural;

   --  The armed paste's write actions in all.
   --
   --  @param Model Model to inspect.
   --  @return Count of items to copy or move (skips excluded).
   function Paste_Execution_Total (Model : Window_Model) return Natural;

   --  Read the journal in Directory and replace Model's history with it, as
   --  a helper does (Files.History_Journal.Read, Files.Model.History.Restore).
   --
   --  @param Directory Helper transport directory.
   --  @param Model Model whose history to replace.
   --  @return True when a complete journal was read and restored.
   function Restore_Journal (Directory : String; Model : in out Window_Model) return Boolean;

   --  Read the journal in Directory and merge it into Model's history, as a
   --  window does when a job ends (Files.Model.History.Merge).
   --
   --  @param Directory Helper transport directory.
   --  @param Model Model whose history to merge into.
   --  @return What reading the journal came to; merged when Read_Whole.
   function Merge_Journal
     (Directory : String;
      Model     : in out Window_Model) return Files.History_Journal.Read_Outcome;

   --  Files.History_Journal.Save_To of Model's history.
   --
   --  @param Directory Helper transport directory.
   --  @param Model Model whose history to save.
   --  @param Mode Must_Commit raises when the snapshot cannot be committed.
   procedure Save_Journal_To
     (Directory : String;
      Model     : Window_Model;
      Mode      : Files.History_Journal.Save_Mode := Files.History_Journal.Best_Effort);

   --  Files.History_Journal.Journals_Newest of Model's history.
   --
   --  @param Model Model whose history to measure.
   --  @param Side Which stack.
   --  @return True when that stack is empty or its newest entry is journaled.
   function Journals_Newest (Model : Window_Model; Side : Files.Undo_History.History_Side) return Boolean;

end Files.Model.Testing;
