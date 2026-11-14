with Ada.Containers.Ordered_Maps;
with Ada.Real_Time;
separate (Files_Suite.Info)
   --  A selection of more folders than one helper takes (Max_Batch, 256) is
   --  measured over several, each folder once; a re-target that still wants
   --  every folder the running helper has left keeps it, and one that drops
   --  one starts afresh; and while work goes on, results are handed over at
   --  most once per Hand_Over_Interval.
   procedure Test_Folder_Size_Batches_And_Hand_Over (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Real_Time.Time;
      package Count_Maps is new Ada.Containers.Ordered_Maps
        (Key_Type => Ada.Strings.Unbounded.Unbounded_String, Element_Type => Natural,
         "<" => Ada.Strings.Unbounded."<");
      Folders : constant := 300;
      Paths   : Files.Folder_Size.Path_Vectors.Vector;
      Scan    : Files.Folder_Size.Session;

      --  Note what was handed over: every folder counted, with its total.
      procedure Note
        (Taken : Files.Folder_Size.Measurement_Vectors.Vector;
         Seen  : in out Count_Maps.Map;
         What  : String) is
      begin
         for Done of Taken loop
            Assert (Done.Result.Available and then Done.Result.File_Count = 1 and then Done.Result.Total_Bytes = 3,
                    What & ": each folder is measured: one file of three bytes; "
                    & Ada.Strings.Unbounded.To_String (Done.Path) & " gave available="
                    & Done.Result.Available'Image & " files=" & Done.Result.File_Count'Image
                    & " bytes=" & Done.Result.Total_Bytes'Image & " items=" & Done.Result.Item_Count'Image);
            if Seen.Contains (Done.Path) then
               Seen.Replace (Done.Path, Seen.Element (Done.Path) + 1);
            else
               Seen.Insert (Done.Path, 1);
            end if;
         end loop;
      end Note;

      procedure Expect_All_Once (Seen : Count_Maps.Map; What : String) is
      begin
         Files_Suite.Support.Assert_Equal (Natural (Seen.Length), Folders, What & ": every folder is measured");
         for Count of Seen loop
            Files_Suite.Support.Assert_Equal (Count, 1, What & ": no folder is measured twice");
         end loop;
      end Expect_All_Once;
   begin
      Reset_Root;
      for Index in 1 .. Folders loop
         declare
            Folder : constant String := Join (Root, "f" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left));
         begin
            Ada.Directories.Create_Directory (Folder);
            Write_Binary_File (Join (Folder, "x"), "abc");
            Paths.Append (Ada.Strings.Unbounded.To_Unbounded_String (Folder));
         end;
      end loop;

      --  More than one helper's worth, and a re-target that still wants
      --  everything: the running helper is kept, not restarted.
      declare
         Seen     : Count_Maps.Map;
         Taken    : Files.Folder_Size.Measurement_Vectors.Vector;
         Reversed : Files.Folder_Size.Path_Vectors.Vector;
      begin
         Files.Folder_Size.Set_Targets (Scan, Paths);
         Files_Suite.Support.Assert_Equal
           (Files.Folder_Size.Testing.Batch_Length (Scan), 256, "one helper takes at most 256 folders");
         declare
            First : constant String := Files.Folder_Size.Testing.Target (Scan);
         begin
            for Path of reverse Paths loop
               Reversed.Append (Path);
            end loop;
            Files.Folder_Size.Set_Targets (Scan, Reversed);
            Files_Suite.Support.Assert_Equal
              (Files.Folder_Size.Testing.Target (Scan), First,
               "a re-target that still wants the running helper's folders keeps it");
         end;
         for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
            Files.Folder_Size.Step (Scan);
            Files.Folder_Size.Take_All (Scan, Taken);
            Note (Taken, Seen, "over several helpers");
            exit when Natural (Seen.Length) >= Folders and then not Files.Folder_Size.Is_Active (Scan);
         end loop;
         Expect_All_Once (Seen, "over several helpers");
      end;

      --  A re-target that drops the running helper's folders starts afresh.
      declare
         Last_Ten : Files.Folder_Size.Path_Vectors.Vector;
      begin
         Files.Folder_Size.Set_Targets (Scan, Paths);
         for Index in Folders - 9 .. Folders loop
            Last_Ten.Append (Paths (Index));
         end loop;
         Files.Folder_Size.Set_Targets (Scan, Last_Ten);
         Files_Suite.Support.Assert_Equal
           (Files.Folder_Size.Testing.Batch_Length (Scan), 10, "a re-target that drops its folders starts afresh");
         Files.Folder_Size.Cancel (Scan);
      end;

      --  The hand-over pace, on a clock of the test's own: an hour ahead, so
      --  the first hand-over is due at once.
      declare
         Seen  : Count_Maps.Map;
         Taken : Files.Folder_Size.Measurement_Vectors.Vector;
         Now   : Ada.Real_Time.Time := Ada.Real_Time.Clock + Ada.Real_Time.Seconds (3_600);
      begin
         Files.Folder_Size.Set_Targets (Scan, Paths);
         for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
            Files.Folder_Size.Step (Scan);
            Files.Folder_Size.Take_Due (Scan, Now, Taken);
            Note (Taken, Seen, "handed over at the interval");
            declare
               Working : constant Boolean := Files.Folder_Size.Is_Active (Scan);
            begin
               --  Just after a hand-over, nothing more while the helper works
               --  (Step alone queues more; nothing has run in between).
               Files.Folder_Size.Take_Due (Scan, Now + Ada.Real_Time.Milliseconds (100), Taken);
               Assert (not Working or else Taken.Is_Empty, "nothing is handed over within the interval while working");
               Note (Taken, Seen, "handed over at the interval");
            end;
            Now := Now + Files.Folder_Size.Hand_Over_Interval;
            exit when Natural (Seen.Length) >= Folders and then not Files.Folder_Size.Is_Active (Scan);
         end loop;
         Expect_All_Once (Seen, "handed over at the interval");
      end;
   end Test_Folder_Size_Batches_And_Hand_Over;
