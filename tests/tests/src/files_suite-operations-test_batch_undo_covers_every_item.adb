separate (Files_Suite.Operations)
   procedure Test_Batch_Undo_Covers_Every_Item (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Status : Zlib.Status_Code;
      Created : Files.Types.String_Vectors.Vector;
      --  More items than one record a second covers in a batch this fast:
      --  every one after the first is left to the record the batch ends with.
      Count : constant := 12;

      function Leaf (Index : Positive) return String is
        ("item" & Character'Val (Character'Pos ('a') + Index - 1));
   begin
      for Extracting in Boolean loop
         Reset_Root;
         for Index in 1 .. Count loop
            Write_Binary_File (Join (Root, Leaf (Index) & ".txt"), Leaf (Index) & " bytes");
            if Extracting then
               Zlib.ZIP_File
                 (Join (Root, Leaf (Index) & ".txt"), Join (Root, Leaf (Index) & ".zip"), Leaf (Index) & ".txt",
                  Status => Status);
               Assert (Status = Zlib.Ok, "prepare archive " & Leaf (Index));
            end if;
         end loop;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Filter (Model, (if Extracting then ".zip" else ".txt"));
         Files.Model.Select_All_Visible (Model);
         Files.Model.Set_Background_Transfers (Model, False);
         Step := Complete_Operation
           (Model, Settings, (if Extracting then Files.Operations.Extract_Selected (Model, Settings)
                              else Files.Operations.Duplicate_Selected (Model, Settings)));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "a large batch succeeds");
         Files_Suite.Support.Assert_Equal
           (Natural (Files.Model.Undo_History (Model).Length), 1, "a large batch records one Undo entry");
         Created := Files.Model.Undo_From_Paths (Model);
         Files_Suite.Support.Assert_Equal
           (Natural (Created.Length), Count, "the entry a large batch ends with covers every item");
         for Path of Created loop
            Assert (Ada.Directories.Exists (To_String (Path)), "every recorded output exists");
         end loop;
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "one Undo reverses a large batch");
         for Path of Created loop
            Assert (not Ada.Directories.Exists (To_String (Path)), "one Undo removes every batch output");
         end loop;
         for Index in 1 .. Count loop
            Assert (Ada.Directories.Exists (Join (Root, Leaf (Index) & ".txt")), "the batch sources are kept");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Batch_Undo_Covers_Every_Item;
