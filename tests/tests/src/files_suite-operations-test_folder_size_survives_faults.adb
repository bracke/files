with Files.Folder_Size.Testing;
with Files.Process_Jobs.Testing;
separate (Files_Suite.Operations)
   --  Folder sizes get an answer through faults: a helper that will not
   --  start answers its batch unmeasured and the folders after it are still
   --  measured; a result that will not open yet is read again, not dropped;
   --  one that never opens is answered unmeasured once the helper is done.
   procedure Test_Folder_Size_Survives_Faults (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Scan  : Files.Folder_Size.Session;
      Taken : Files.Folder_Size.Measurement_Vectors.Vector;

      function Folders (Count : Positive) return Files.Folder_Size.Path_Vectors.Vector is
         Paths : Files.Folder_Size.Path_Vectors.Vector;
      begin
         Reset_Root;
         for Index in 1 .. Count loop
            declare
               Folder : constant String := Join (Root, "g" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left));
            begin
               Ada.Directories.Create_Directory (Folder);
               Write_Binary_File (Join (Folder, "x"), "abc");
               Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Folder));
            end;
         end loop;
         return Paths;
      end Folders;

      --  Step until every folder has an answer; count the measured ones.
      procedure Measure_All (Count : Positive; Measured, Unmeasured : out Natural; What : String) is
      begin
         Measured := 0;
         Unmeasured := 0;
         for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
            Files.Folder_Size.Step (Scan);
            Files.Folder_Size.Take_All (Scan, Taken);
            for Done of Taken loop
               if Done.Result.Available then
                  Assert (Done.Result.File_Count = 1 and then Done.Result.Total_Bytes = 3,
                          What & ": a measured folder holds one file of three bytes");
                  Measured := Measured + 1;
               else
                  Unmeasured := Unmeasured + 1;
               end if;
            end loop;
            exit when Measured + Unmeasured >= Count and then not Files.Folder_Size.Is_Active (Scan);
         end loop;
         Files_Suite.Support.Assert_Equal (Measured + Unmeasured, Count, What & ": every folder is answered once");
      end Measure_All;

      Measured, Unmeasured : Natural;
   begin
      --  The first helper (256 folders) will not start; the other 44 must
      --  still be measured rather than wait for a change of selection.
      Files.Process_Jobs.Testing.Refuse_Next_Launch;
      Files.Folder_Size.Set_Targets (Scan, Folders (300));
      Measure_All (300, Measured, Unmeasured, "after a refused launch");
      Files_Suite.Support.Assert_Equal (Unmeasured, 256, "the refused helper's batch is answered unmeasured");
      Files_Suite.Support.Assert_Equal (Measured, 44, "the folders after it are measured");

      --  Results that will not open at first are read again.
      Files.Folder_Size.Testing.Fail_Result_Reads (3);
      Files.Folder_Size.Set_Targets (Scan, Folders (4));
      Measure_All (4, Measured, Unmeasured, "with results slow to open");
      Files.Folder_Size.Testing.Fail_Result_Reads (0);
      Files_Suite.Support.Assert_Equal (Measured, 4, "a result that opens late is still measured");

      --  Results that never open are answered unmeasured once the helper ends.
      Files.Folder_Size.Testing.Fail_Result_Reads (Natural'Last);
      Files.Folder_Size.Set_Targets (Scan, Folders (2));
      Measure_All (2, Measured, Unmeasured, "with results that never open");
      Files.Folder_Size.Testing.Fail_Result_Reads (0);
      Files_Suite.Support.Assert_Equal (Unmeasured, 2, "a result that never opens is answered unmeasured");
      Files.Folder_Size.Cancel (Scan);
   exception
      when others =>
         Files.Folder_Size.Testing.Fail_Result_Reads (0);
         Files.Folder_Size.Cancel (Scan);
         raise;
   end Test_Folder_Size_Survives_Faults;
