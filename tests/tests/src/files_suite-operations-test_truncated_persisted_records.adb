separate (Files_Suite.Operations)
   procedure Test_Truncated_Persisted_Records
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element_Offset;

      Job_Path         : constant String := Join (Root, "complete-job-record");
      History_Directory : constant String := Join (Root, "prefix-history");
      History_Path     : constant String := Join (History_Directory, "history");
      File             : Ada.Streams.Stream_IO.File_Type;
      Written_Result   : Files.Operations.Operation_Result;
      Read_Result      : Files.Operations.Operation_Result;
      Model            : Files.Model.Window_Model;

      function Read_All
        (Path : String) return Ada.Streams.Stream_Element_Array
      is
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Path);
         declare
            Length : constant Ada.Streams.Stream_Element_Offset :=
              Ada.Streams.Stream_Element_Offset
                (Ada.Streams.Stream_IO.Size (File));
            Data : Ada.Streams.Stream_Element_Array (1 .. Length);
            Last : Ada.Streams.Stream_Element_Offset;
         begin
            Ada.Streams.Stream_IO.Read (File, Data, Last);
            Ada.Streams.Stream_IO.Close (File);
            Assert (Last = Data'Last, "persisted-record fixture reads every byte");
            return Data;
         end;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Read_All;

      procedure Write_Prefix
        (Path  : String;
         Data  : Ada.Streams.Stream_Element_Array;
         Count : Natural)
      is
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Path);
         if Count > 0 then
            Ada.Streams.Stream_IO.Write
              (File,
               Data
                 (Data'First ..
                    Data'First
                      + Ada.Streams.Stream_Element_Offset (Count) - 1));
         end if;
         Ada.Streams.Stream_IO.Close (File);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Write_Prefix;
   begin
      Reset_Root;
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Job_Path);
      Files.Job_Records.Write_Operation_Result
        (Ada.Streams.Stream_IO.Stream (File), Written_Result);
      Ada.Streams.Stream_IO.Close (File);

      declare
         Data : constant Ada.Streams.Stream_Element_Array :=
           Read_All (Job_Path);
      begin
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Job_Path);
         Read_Result := Files.Job_Records.Read_Operation_Result
           (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         Files_Suite.Support.Assert_Equal
           (Read_Result.Status,
            Written_Result.Status,
            "the complete job record decodes before prefix mutation");

         for Prefix_Length in 0 .. Natural (Data'Length) - 1 loop
            Write_Prefix (Job_Path, Data, Prefix_Length);
            Ada.Streams.Stream_IO.Open
              (File, Ada.Streams.Stream_IO.In_File, Job_Path);
            declare
               Rejected : Boolean := False;
            begin
               begin
                  Read_Result := Files.Job_Records.Read_Operation_Result
                    (Ada.Streams.Stream_IO.Stream (File));
               exception
                  when others =>
                     Rejected := True;
               end;
               Ada.Streams.Stream_IO.Close (File);
               Assert
                 (Rejected,
                  "strict job-record prefix is rejected at byte"
                  & Natural'Image (Prefix_Length));
            end;
         end loop;
      end;

      Ada.Directories.Create_Directory (History_Directory);
      Files.History_Journal.Save_Stacks
        (History_Directory,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Files.Model.Undo_Entry_Vectors.Empty_Vector,
         Required => True);
      Files.Model.Initialize
        (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Assert
        (Files.History_Journal.Restore (History_Directory, Model),
         "the complete history record decodes before prefix mutation");

      declare
         Data : constant Ada.Streams.Stream_Element_Array :=
           Read_All (History_Path);
      begin
         for Prefix_Length in 0 .. Natural (Data'Length) - 1 loop
            Write_Prefix (History_Path, Data, Prefix_Length);
            Assert
              (not Files.History_Journal.Restore
                 (History_Directory, Model),
               "strict history-record prefix is rejected at byte"
               & Natural'Image (Prefix_Length));
         end loop;
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Truncated_Persisted_Records;
