with Files.Model.Testing;
with Files.Operation_Results;
separate (Files_Suite.Transfer)
   procedure Test_Drop_Import_Progress (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "dropp-src");
      Dest_Dir : constant String := Join (Root, "dropp-dest");
      Count    : constant := 40;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Sources  : Files.Types.String_Vectors.Vector;
      Routed   : Files.Controller.Controller_Result;
      Step     : Files.Operation_Results.Operation_Result;

      function Src (N : Positive) return String is (Numbered_File (Src_Dir, N));
      function Dest (N : Positive) return String is (Numbered_File (Dest_Dir, N));
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      for N in 1 .. Count loop
         Write_File (Src (N), "S" & Files.Types.Natural_Text (N));
         Sources.Append (To_Unbounded_String (Src (N)));
      end loop;

      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);

      --  A collision-free drop arms the resumable executor and runs the first
      --  batch; a set larger than one batch keeps the progress state active.
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operation_Results.Operation_Success,
         "large drop import reports success");
      Assert (Files.Model.Foreground_Job_Is_Active (Model), "a large drop keeps the progress executor active");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Testing.Paste_Execution_Total (Model),
         Count,
         "the drop progress total counts every source");
      Assert (Files.Model.Testing.Paste_Execution_Done (Model) < Count,
              "the first drop batch does not finish the whole set");

      Step := Files.Jobs.Foreground.Advance (Model, Settings, Count);
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operation_Results.Operation_Success,
         "advancing the drop executor reports success");
      Assert (not Files.Model.Foreground_Job_Is_Active (Model), "the drop executor finalizes after the last batch");

      for N in 1 .. Count loop
         Assert (Ada.Directories.Exists (Dest (N)), "every dropped source is imported to the destination");
         Assert (Ada.Directories.Exists (Src (N)), "a dropped copy leaves the sources in place");
      end loop;
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         Count,
         "the collision-free drop refreshes the destination model");
   end Test_Drop_Import_Progress;
