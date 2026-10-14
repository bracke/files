with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;

package body Files.Transfer_Jobs.Testing is
   use Ada.Strings.Unbounded;

   Max_Path_Length : constant := 32 * 1024;
   Max_Token_Length : constant := 2 * 1024;
   Max_Error_Length : constant := 256;
   Request_Header : constant String := "files-transfer-request-1";
   Result_Header : constant String := "files-transfer-result-1";

   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Write_Bounded
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Maximum : Natural)
   is
   begin
      if Value'Length > Maximum then
         raise Constraint_Error;
      end if;
      String'Output (Stream, Value);
   end Write_Bounded;

   procedure Write_Request
     (Path : String;
      Action : Files.Paste.Resolved_Action;
      Mode : Files.File_System.Drop_Import_Mode;
      Batch_Directory : String := "")
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Stream : Ada.Streams.Stream_IO.Stream_Access;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Stream := Ada.Streams.Stream_IO.Stream (File);
      String'Output (Stream, Request_Header);
      Write_Bounded (Stream, To_String (Action.Source_Path), Max_Path_Length);
      Write_Bounded (Stream, To_String (Action.Dest_Path), Max_Path_Length);
      Boolean'Output (Stream, Action.Skip);
      Boolean'Output (Stream, Action.Replaced);
      Files.File_System.Drop_Import_Mode'Output (Stream, Mode);
      Write_Bounded (Stream, Batch_Directory, Max_Path_Length);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others => Close (File); raise;
   end Write_Request;

   function Read_Request_Action
     (Path : String) return Files.Paste.Resolved_Action
   is
      Result : Files.Paste.Resolved_Action;
      Mode : Files.File_System.Drop_Import_Mode;
      Batch_Directory : Unbounded_String;
   begin
      Read_Transport_Request
        (Path, Result, Mode, Batch_Directory);
      pragma Unreferenced (Mode);
      pragma Unreferenced (Batch_Directory);
      return Result;
   end Read_Request_Action;

   procedure Write_Result
     (Path : String;
      Result : Job_Result)
   is
      File : Ada.Streams.Stream_IO.File_Type;
      Stream : Ada.Streams.Stream_IO.Stream_Access;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Stream := Ada.Streams.Stream_IO.Stream (File);
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Result.Mutation.Success);
      Write_Bounded
        (Stream, To_String (Result.Mutation.Error_Key), Max_Error_Length);
      Boolean'Output (Stream, Result.Cancelled);
      Write_Bounded (Stream, To_String (Result.Trashed), Max_Path_Length);
      Write_Bounded
        (Stream, To_String (Result.Trashed_Identity), Max_Token_Length);
      Write_Bounded
        (Stream, To_String (Result.Created_Identity), Max_Token_Length);
      Write_Bounded
        (Stream, To_String (Result.Created_Tree_Revision), Max_Token_Length);
      Boolean'Output (Stream, Result.Recovered);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others => Close (File); raise;
   end Write_Result;

   function Read_Result (Path : String) return Job_Result is
     (Read_Transport_Result (Path));

   function Replacement_Checkpoint_Is_Valid (Path : String) return Boolean is
      Backup, Identity : Files.Types.UString;
   begin
      Read_Replacement_Checkpoint (Path, Backup, Identity);
      return Length (Backup) > 0 and then Length (Identity) > 0;
   exception
      when others => return False;
   end Replacement_Checkpoint_Is_Valid;
end Files.Transfer_Jobs.Testing;
