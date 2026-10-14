with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;

with Files.Job_Records;

package body Files.Refresh_Jobs.Testing is
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_IO.Count;

   function Request_Paths_Are_Valid
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean is
     (Request_Paths_Are_Consistent (Root, Previous_Path, Recent));

   function Watch_Request_Path_Is_Valid (Path : String) return Boolean is
     (Watch_Path_Is_Consistent (Path));

   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Replace_Result_Flags
     (Path     : String;
      Success  : Boolean;
      Reloaded : Boolean)
   is
      File        : Ada.Streams.Stream_IO.File_Type;
      Flags_File  : Ada.Streams.Stream_IO.File_Type;
      Flags_Path  : constant String := Path & ".test-flags";
      Flags_First : Ada.Streams.Stream_IO.Count;
      Flags_Last  : Ada.Streams.Stream_IO.Count;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      declare
         Header : constant String :=
           Files.Job_Records.Read_String
             (Ada.Streams.Stream_IO.Stream (File), 128);
         Original_Success : Boolean;
         Original_Reloaded : Boolean;
         pragma Unreferenced (Header, Original_Success, Original_Reloaded);
      begin
         Flags_First := Ada.Streams.Stream_IO.Index (File);
         Original_Success := Boolean'Input (Ada.Streams.Stream_IO.Stream (File));
         Original_Reloaded := Boolean'Input (Ada.Streams.Stream_IO.Stream (File));
         Flags_Last := Ada.Streams.Stream_IO.Index (File);
      end;
      Ada.Streams.Stream_IO.Close (File);

      Ada.Streams.Stream_IO.Create
        (Flags_File, Ada.Streams.Stream_IO.Out_File, Flags_Path);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (Flags_File), Success);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (Flags_File), Reloaded);
      Ada.Streams.Stream_IO.Close (Flags_File);

      declare
         Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Path));
         Flags_Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Flags_Path));
         Data : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Size));
         Replacement : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Flags_Size));
         Last : Ada.Streams.Stream_Element_Offset;
         Replacement_Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Flags_Size /= Flags_Last - Flags_First then
            raise Program_Error;
         end if;
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
         Ada.Streams.Stream_IO.Read (File, Data, Last);
         Ada.Streams.Stream_IO.Close (File);
         Ada.Streams.Stream_IO.Open
           (Flags_File, Ada.Streams.Stream_IO.In_File, Flags_Path);
         Ada.Streams.Stream_IO.Read
           (Flags_File, Replacement, Replacement_Last);
         Ada.Streams.Stream_IO.Close (Flags_File);
         if Last /= Data'Last or else Replacement_Last /= Replacement'Last then
            raise Program_Error;
         end if;
         for Offset in Replacement'Range loop
            Data
              (Ada.Streams.Stream_Element_Offset (Flags_First) + Offset - 1) :=
                Replacement (Offset);
         end loop;
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Write (File, Data);
         Ada.Streams.Stream_IO.Close (File);
      end;
      Ada.Directories.Delete_File (Flags_Path);
   exception
      when others =>
         Close (File);
         Close (Flags_File);
         begin
            if Ada.Directories.Exists (Flags_Path) then
               Ada.Directories.Delete_File (Flags_Path);
            end if;
         exception
            when others => null;
         end;
         raise;
   end Replace_Result_Flags;

   function Claim_Notification (Directory : String) return Boolean is
     (Claim_Watch_Notification (Directory));

   function Post_Notification (Directory : String) return Boolean is
     (Post_Watch_Notification (Directory));

   function Watch_Target (Job : Watch_Session) return String is
     (Ada.Strings.Unbounded.To_String (Job.Path));
end Files.Refresh_Jobs.Testing;
