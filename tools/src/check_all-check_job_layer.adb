separate (Check_All)
   procedure Check_Job_Layer is
      --  Files.Jobs sits below the file system: it reaches File_System only
      --  through the Files.Jobs.Storage port, and nothing above it at all.
      --  The with clauses are parsed in every spec, body and subunit of the
      --  family, so a new unit or a split body stays covered.
      Above : constant String_List :=
        [To_Unbounded_String ("Files.File_System"),
         To_Unbounded_String ("Files.Undo"),
         To_Unbounded_String ("Files.Model"),
         To_Unbounded_String ("Files.Operations"),
         To_Unbounded_String ("Files.Refresh"),
         To_Unbounded_String ("Files.Transfer_Jobs"),
         To_Unbounded_String ("Files.Job_Payloads"),
         To_Unbounded_String ("Files.Job_Drivers"),
         To_Unbounded_String ("Files.Settings"),
         To_Unbounded_String ("Files.Localization"),
         To_Unbounded_String ("Files.Commands"),
         To_Unbounded_String ("Files.Controller"),
         To_Unbounded_String ("Files.Interaction"),
         To_Unbounded_String ("Files.Events"),
         To_Unbounded_String ("Files.Overlays"),
         To_Unbounded_String ("Files.Rendering"),
         To_Unbounded_String ("Files.Application")];
      --  A leaf type unit whose name starts like the file system's.
      Leaf_Types : constant String_List := [To_Unbounded_String ("Files.File_System_Types")];
   begin
      for Pattern of String_List'[To_Unbounded_String ("files-jobs.ad?"), To_Unbounded_String ("files-jobs-*.ad?")]
      loop
         for Item of Project_Tools.Files.List_Tree (Root & "/src", To_String (Pattern), Generated_Directories) loop
            for Prefix of Above loop
               Require_Only_Allowed_With_Clauses (To_String (Item), To_String (Prefix), Leaf_Types);
            end loop;
         end loop;
      end loop;
   end Check_Job_Layer;
