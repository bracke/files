separate (Check_All.Check_Rendering_Architecture)
   --  Every files-rendering* source, specs and bodies, children and
   --  subunits alike, read and stripped of comments once and held to every
   --  pattern below. A source is visited once, so a violation is reported
   --  once, naming the file.
   procedure Check_Rendering_Sources is
      type Rule is record
         Pattern : Unbounded_String;
         Message : Unbounded_String;
      end record;

      function "+" (Text : String) return Unbounded_String renames To_Unbounded_String;

      --  Model mutators, the parent's and every child's, are covered
      --  family-wide by Check_Rendering_Model_Reads, derived from the specs.
      --  The snapshot and frame read nothing from disk either: a stat per
      --  item there would run on every rebuild.
      Rules : constant array (Positive range <>) of Rule :=
        [
         (+"with Ada.Directories;",
          +"must not import Ada.Directories for filesystem access"),
         (+"Ada.Directories.",
          +"must not perform filesystem access"),
         (+"Files.Operations.",
          +"must not execute operations"),
         (+"with Files.Operations",
          +"must not depend on operations"),
         (+"with Files.Controller",
          +"must not depend on the controller"),
         (+"with Files.Application",
          +"must not depend on application startup"),
         (+"with Files.Interaction",
          +"must not depend on the interaction reducer"),
         (+"Files.Controller.",
          +"must not route controller actions"),
         (+"Files.Application.",
          +"must not call application startup logic"),
         (+"Execute_Pure_Command",
          +"must not dispatch commands"),
         (+"Files.Commands.Find_By_Shortcut",
          +"must not translate input shortcuts"),
         (+"with GNAT.OS_Lib;",
          +"must not import OS process bindings"),
         (+"GNAT.OS_Lib.",
          +"must not call OS process bindings"),
         (+"GNAT.Expect.",
          +"must not call process interaction bindings"),
         (+"Create_Process",
          +"must not create external processes"),
         (+"Spawn",
          +"must not spawn external processes"),
         (+"Files.Settings.Add_Extension_Mapping",
          +"must not mutate settings extension mappings"),
         (+"Files.Settings.Add_Icon_Mapping",
          +"must not mutate settings icon mappings"),
         (+"Files.Settings.Add_Open_Action",
          +"must not mutate settings open-action mappings"),
         (+"Files.Settings.Drafts.Apply_Draft",
          +"must not apply settings drafts"),
         (+"Files.Settings.Storage.Ensure_Default_File",
          +"must not create settings files"),
         (+"Files.Settings.Storage.Save_Text",
          +"must not write settings text"),
         (+"Files.Settings.Storage.Load_File",
          +"must not load settings files"),
         (+"Hostkit.",
          +"must not do I/O (Hostkit.)"),
         (+"Ada.Text_IO",
          +"must not do I/O (Ada.Text_IO)"),
         (+"Ada.Streams.Stream_IO",
          +"must not do I/O (Ada.Streams.Stream_IO)"),
         (+"Files.IO.Capped_Files",
          +"must not do I/O (Files.IO.Capped_Files)"),
         (+"Files.IO.Fs_Primitives",
          +"must not do I/O (Files.IO.Fs_Primitives)")];

      Seen : Natural := 0;
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "files-rendering*.ad?", Generated_Directories) loop
         declare
            Path : constant String := To_String (Item);
            Code : constant String :=
              Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True);
         begin
            Seen := Seen + 1;
            for R of Rules loop
               if Ada.Strings.Fixed.Index (Code, To_String (R.Pattern)) > 0 then
                  Report (Path & ": rendering " & To_String (R.Message));
               end if;
            end loop;
         end;
      end loop;
      --  An empty listing would make every rule pass vacuously.
      if Seen < 100 then
         Report ("Check_Rendering_Sources saw only" & Seen'Image & " files-rendering sources; the listing is broken");
      end if;
   end Check_Rendering_Sources;
