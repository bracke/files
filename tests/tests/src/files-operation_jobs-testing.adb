with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;

with Files.Job_Records;

package body Files.Operation_Jobs.Testing is
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_IO.Count;

   function Request_Path_Is_Valid
     (Root   : String;
      Recent : Boolean) return Boolean is
     (Request_Path_Is_Consistent (Root, Recent));

   procedure Close (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         Ada.Streams.Stream_IO.Close (File);
      end if;
   exception
      when others => null;
   end Close;

   procedure Replace_Result_Kind
     (Path : String;
      Kind : Operation_Kind)
   is
      File       : Ada.Streams.Stream_IO.File_Type;
      Kind_File  : Ada.Streams.Stream_IO.File_Type;
      Kind_Path  : constant String := Path & ".test-kind";
      Kind_First : Ada.Streams.Stream_IO.Count;
      Kind_Last  : Ada.Streams.Stream_IO.Count;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      declare
         Header : constant String := Files.Job_Records.Read_String (Ada.Streams.Stream_IO.Stream (File), 128);
         pragma Unreferenced (Header);
      begin
         Kind_First := Ada.Streams.Stream_IO.Index (File);
         declare
            Original : constant Operation_Kind :=
              Operation_Kind'Input (Ada.Streams.Stream_IO.Stream (File));
            pragma Unreferenced (Original);
         begin
            null;
         end;
         Kind_Last := Ada.Streams.Stream_IO.Index (File);
      end;
      Ada.Streams.Stream_IO.Close (File);

      Ada.Streams.Stream_IO.Create
        (Kind_File, Ada.Streams.Stream_IO.Out_File, Kind_Path);
      Operation_Kind'Output (Ada.Streams.Stream_IO.Stream (Kind_File), Kind);
      Ada.Streams.Stream_IO.Close (Kind_File);

      declare
         Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Path));
         Kind_Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Kind_Path));
         Data : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Size));
         Replacement : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Kind_Size));
         Last : Ada.Streams.Stream_Element_Offset;
         Replacement_Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Kind_Size /= Kind_Last - Kind_First then
            raise Program_Error;
         end if;
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
         Ada.Streams.Stream_IO.Read (File, Data, Last);
         Ada.Streams.Stream_IO.Close (File);
         Ada.Streams.Stream_IO.Open
           (Kind_File, Ada.Streams.Stream_IO.In_File, Kind_Path);
         Ada.Streams.Stream_IO.Read
           (Kind_File, Replacement, Replacement_Last);
         Ada.Streams.Stream_IO.Close (Kind_File);
         if Last /= Data'Last or else Replacement_Last /= Replacement'Last then
            raise Program_Error;
         end if;
         for Offset in Replacement'Range loop
            Data
              (Ada.Streams.Stream_Element_Offset (Kind_First) + Offset - 1) :=
                Replacement (Offset);
         end loop;
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Write (File, Data);
         Ada.Streams.Stream_IO.Close (File);
      end;
      Ada.Directories.Delete_File (Kind_Path);
   exception
      when others =>
         Close (File);
         Close (Kind_File);
         begin
            if Ada.Directories.Exists (Kind_Path) then
               Ada.Directories.Delete_File (Kind_Path);
            end if;
         exception
            when others => null;
         end;
         raise;
   end Replace_Result_Kind;

   procedure Replace_Result_Recent
     (Path   : String;
      Recent : Boolean)
   is
      File         : Ada.Streams.Stream_IO.File_Type;
      Recent_File  : Ada.Streams.Stream_IO.File_Type;
      Recent_Path  : constant String := Path & ".test-recent";
      Recent_First : Ada.Streams.Stream_IO.Count;
      Recent_Last  : Ada.Streams.Stream_IO.Count;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      declare
         Header : constant String :=
           Files.Job_Records.Read_String
             (Ada.Streams.Stream_IO.Stream (File), 128);
         Kind : constant Operation_Kind :=
           Operation_Kind'Input (Ada.Streams.Stream_IO.Stream (File));
         pragma Unreferenced (Header, Kind);
      begin
         Recent_First := Ada.Streams.Stream_IO.Index (File);
         declare
            Original : constant Boolean :=
              Boolean'Input (Ada.Streams.Stream_IO.Stream (File));
            pragma Unreferenced (Original);
         begin
            null;
         end;
         Recent_Last := Ada.Streams.Stream_IO.Index (File);
      end;
      Ada.Streams.Stream_IO.Close (File);

      Ada.Streams.Stream_IO.Create
        (Recent_File, Ada.Streams.Stream_IO.Out_File, Recent_Path);
      Boolean'Output (Ada.Streams.Stream_IO.Stream (Recent_File), Recent);
      Ada.Streams.Stream_IO.Close (Recent_File);

      declare
         Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Path));
         Recent_Size : constant Ada.Streams.Stream_IO.Count :=
           Ada.Streams.Stream_IO.Count (Ada.Directories.Size (Recent_Path));
         Data : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Size));
         Replacement : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Recent_Size));
         Last : Ada.Streams.Stream_Element_Offset;
         Replacement_Last : Ada.Streams.Stream_Element_Offset;
      begin
         if Recent_Size /= Recent_Last - Recent_First then
            raise Program_Error;
         end if;
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
         Ada.Streams.Stream_IO.Read (File, Data, Last);
         Ada.Streams.Stream_IO.Close (File);
         Ada.Streams.Stream_IO.Open
           (Recent_File, Ada.Streams.Stream_IO.In_File, Recent_Path);
         Ada.Streams.Stream_IO.Read
           (Recent_File, Replacement, Replacement_Last);
         Ada.Streams.Stream_IO.Close (Recent_File);
         if Last /= Data'Last or else Replacement_Last /= Replacement'Last then
            raise Program_Error;
         end if;
         for Offset in Replacement'Range loop
            Data
              (Ada.Streams.Stream_Element_Offset (Recent_First) + Offset - 1) :=
                Replacement (Offset);
         end loop;
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Write (File, Data);
         Ada.Streams.Stream_IO.Close (File);
      end;
      Ada.Directories.Delete_File (Recent_Path);
   exception
      when others =>
         Close (File);
         Close (Recent_File);
         begin
            if Ada.Directories.Exists (Recent_Path) then
               Ada.Directories.Delete_File (Recent_Path);
            end if;
         exception
            when others => null;
         end;
         raise;
   end Replace_Result_Recent;
end Files.Operation_Jobs.Testing;
