with Files.UI_Types;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Files.Undo.Journal;
with Files.Jobs.Records;
with Files.Model.History;
with Files.Model.Selection;
with Files.Operations;
with Files.Jobs.Process;
with Hostkit.Fs;

package body Files.Jobs.Operation.Helper is
   use Ada.Strings.Unbounded;

   procedure Run (Directory : String) is
      Work  : Request;
      Done  : Outcome;
      Model : Files.Model.Window_Model;

      procedure Write (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Write_Outcome (Stream, Done);
      end Write;
   begin
      Work := Read_Request (Hostkit.Fs.Join (Directory, Files.Jobs.Process.Request_File));
      Done.Kind := Work.Kind;
      Files.Model.Initialize (Model, To_String (Work.Root), Work.Selected, Hostkit.Fs.Home_Directory);
      if Work.Recent then
         Files.Model.Navigate_Recent (Model, Work.Selected);
      end if;
      declare
         use type Files.Undo.Journal.Read_Outcome;
         Journal : Files.Undo.Journal.Journal_Contents;
      begin
         if Files.Undo.Journal.Read (Directory, Journal) /= Files.Undo.Journal.Read_Whole then
            raise Ada.IO_Exceptions.Data_Error;
         end if;
         Files.Model.History.Restore (Model, Journal.Undo, Journal.Redo, Journal.State);
      end;
      Files.Undo.Journal.Save
        (Files.Model.History.State (Model),
         Mode =>
           (if Work.Kind in Trash | Undo | Redo then Files.Undo.Journal.Must_Commit
            else Files.Undo.Journal.Best_Effort));
      if Work.Kind in Search_Names | Search_Contents then
         Files.Model.Set_Filter (Model, To_String (Work.Query));
      else
         Files.Model.Selection.Select_All_Visible (Model);
      end if;
      Done.Result :=
        (case Work.Kind is
            when Duplicate => Files.Operations.Duplicate_Selected (Model, Work.Settings),
            when Compress_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Zip_Archive),
            when Compress_Seven_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Seven_Zip_Archive),
            when Extract => Files.Operations.Extract_Selected (Model, Work.Settings),
            when Search_Names => Files.Operations.Run_Search (Model, Work.Settings, Files.UI_Types.Search_Names),
            when Search_Contents => Files.Operations.Run_Search (Model, Work.Settings, Files.UI_Types.Search_Contents),
            when Trash => Files.Operations.Delete_Selected (Model, Work.Settings),
            when Delete_Permanently => Files.Operations.Delete_Selected_Permanently (Model, Work.Settings),
            when Restore => Files.Operations.Restore_Selected_From_Trash (Model, Work.Settings),
            when Empty_Trash => Files.Operations.Empty_Trash (Model, Work.Settings),
            when Undo => Files.Operations.Undo_Last (Model, Work.Settings),
            when Redo => Files.Operations.Redo_Last (Model, Work.Settings));
      Files.Undo.Journal.Save (Files.Model.History.State (Model));
      Done.Visible_Error := To_Unbounded_String
        (if Files.Model.Last_Error_Key (Model) = "" then To_String (Done.Result.Error_Key)
         else Files.Model.Last_Error_Key (Model));
      Done.Recent := Files.Model.In_Recent_View (Model);
      Done.Selection := To_Unbounded_String (Files.Model.Selection.Selected_Name (Model));
      for Row of Files.Model.Visible_Rows (Model) loop
         Done.Items.Append (Row.Item);
      end loop;
      Done.Signature := Files.Model.Directory_Signature_Of (Model);
      Done.Moves := Files.Model.Take_Path_Moves (Model);
      Files.Jobs.Records.Publish_Result (Directory, Write'Access);
   end Run;

end Files.Jobs.Operation.Helper;
