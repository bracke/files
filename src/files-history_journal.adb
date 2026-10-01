with Ada.Streams.Stream_IO;
with Ada.Directories;
with Files.Durable_Writes;
with Files.Job_Context;
with Hostkit.Fs;

package body Files.History_Journal is
   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Write (Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector; Required : Boolean := False) is
      Directory : constant String := Files.Job_Context.Directory;
      File : Ada.Streams.Stream_IO.File_Type;
      Published : Boolean;
   begin
      if Directory = "" then
         return;
      end if;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "history.tmp"));
      Files.Model.Undo_Entry_Vectors.Vector'Output (Ada.Streams.Stream_IO.Stream (File), Undo);
      Files.Model.Undo_Entry_Vectors.Vector'Output (Ada.Streams.Stream_IO.Stream (File), Redo);
      Ada.Streams.Stream_IO.Close (File);
      Published := Files.Durable_Writes.Publish
        (Hostkit.Fs.Join (Directory, "history.tmp"), Hostkit.Fs.Join (Directory, "history"));
      if Required and then not Published then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         Close (File);
         if Required then
            raise;
         end if;
   end Write;

   procedure Save (Model : Files.Model.Window_Model; Required : Boolean := False) is
   begin
      Write (Files.Model.Undo_History (Model), Files.Model.Redo_History (Model), Required);
   end Save;

   procedure Checkpoint (Model : Files.Model.Window_Model; Action : Files.Model.Undo_Entry; Redo : Boolean) is
      Undo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Undo_History (Model);
      Redo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Redo_History (Model);
   begin
      if Redo then
         Redo_Stack.Append (Action);
      else
         Undo_Stack.Append (Action);
      end if;
      Write (Undo_Stack, Redo_Stack, Required => True);
   end Checkpoint;

   function Restore (Directory : String; Model : in out Files.Model.Window_Model) return Boolean is
      File : Ada.Streams.Stream_IO.File_Type;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "history"));
      Undo := Files.Model.Undo_Entry_Vectors.Vector'Input (Ada.Streams.Stream_IO.Stream (File));
      Redo := Files.Model.Undo_Entry_Vectors.Vector'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Files.Model.Set_History (Model, Undo, Redo);
      return True;
   exception
      when others =>
         Close (File);
         return False;
   end Restore;
end Files.History_Journal;
