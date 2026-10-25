separate (Files_Suite.Operations)
   procedure Test_Desktop_Exec_Expansion (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Apps_Dir : constant String := Join (Join (Root, "xdg_apps"), "applications");

      function Find
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Applications.Application renames Find_Application;

      procedure Check is
         Apps : constant Files.Applications.Application_Vectors.Vector :=
           Files.Applications.Available_Applications;
         Viewer : constant Files.Applications.Application := Find (Apps, "Image Viewer");
         Quoted : constant Files.Applications.Application := Find (Apps, "Quoted App");
         Localized : constant Files.Applications.Application :=
           Find (Apps, "Dansk Program");
      begin
         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Localized, Targets);
            declare
               Context : constant String := "localized values and two-stage desktop escapes expand correctly";
            begin
               Files_Suite.Support.Assert_Equal (To_String (Localized.Icon), "regional\icon", Context & ": icon");
               Files_Suite.Support.Assert_Equal
                 (Natural (Action.Arguments.Length), 6, Context & ": argument count");
               Files_Suite.Support.Assert_Equal
                 (To_String (Action.Arguments.Element (1)), "--label=Dansk Program", Context & ": argument 1");
               Files_Suite.Support.Assert_Equal
                 (To_String (Action.Arguments.Element (2)), "C:\Temp", Context & ": argument 2");
               Files_Suite.Support.Assert_Equal
                 (To_String (Action.Arguments.Element (5)), "--icon", Context & ": argument 5");
               Files_Suite.Support.Assert_Equal
                 (To_String (Action.Arguments.Element (6)), "regional\icon", Context & ": argument 6");
            end;
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Viewer, Targets);
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Executable),
               "viewer",
               "action executable is the first Exec token");
            Assert
              (not Action.Use_Shell,
               "open-with action is not shell-wrapped");
            Files_Suite.Support.Assert_Equal
              (Natural (Action.Arguments.Length),
               3,
               "arguments are remaining Exec tokens followed by each target");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (1)),
               "--open",
               "base Exec argument is preserved");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (2)),
               "/tmp/a.txt",
               "first target path is appended");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (3)),
               "/tmp/b.txt",
               "second target path is appended");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a file.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Action := Files.Applications.Build_Open_Action (Quoted, Targets);
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Executable),
               "/opt/Quoted Editor/bin/editor",
               "a quoted desktop executable remains one executable token");
            Files_Suite.Support.Assert_Equal
              (Natural (Action.Arguments.Length),
               9,
               "quoted arguments and desktop field codes expand to the expected vector");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (1)),
               "--mode=two words",
               "a quoted desktop argument remains one argument");
            Assert
              (To_String (Action.Arguments.Element (2)) = "/tmp/a file.txt"
               and then To_String (Action.Arguments.Element (3)) = "/tmp/b.txt",
               "a list field code expands in place with argument boundaries intact");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (4)),
               "--after",
               "arguments after the target field keep their position");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (5)),
               "%",
               "a doubled percent becomes one literal percent argument");
            Files_Suite.Support.Assert_Equal
              (To_String (Action.Arguments.Element (6)),
               "Quoted App",
               "the application-name field expands as one argument");
            Assert
              (To_String (Action.Arguments.Element (7)) = "--icon"
               and then To_String (Action.Arguments.Element (8)) = "quoted-icon",
               "the icon field expands to its two specified arguments");
            Assert
              (Hostkit.Metadata.Same_File
                 (To_String (Action.Arguments.Element (9)),
                  Join (Apps_Dir, "quoted.desktop")),
               "the desktop-file field expands to the source desktop entry");
         end;

         declare
            Targets : Files.Types.String_Vectors.Vector;
            Single_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Single Target"),
               Exec         => To_Unbounded_String ("viewer --before %f --after"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Percent_App : constant Files.Applications.Application :=
              (Name         => To_Unbounded_String ("Percent Executable"),
               Exec         => To_Unbounded_String ("viewer%%tool %F"),
               Icon         => Null_Unbounded_String,
               Desktop_File => Null_Unbounded_String);
            Actions : Files.Applications.Open_Action_Vectors.Vector;
            Action  : Files.Settings.Open_Action;
         begin
            Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
            Targets.Append (To_Unbounded_String ("/tmp/b.txt"));
            Actions := Files.Applications.Build_Open_Actions (Single_App, Targets);
            declare
               Context : constant String := "single-file fields produce one positional launch per selected target";
            begin
               Files_Suite.Support.Assert_Equal (Natural (Actions.Length), 2, Context & ": launch count");
               Files_Suite.Support.Assert_Equal
                 (Natural (Actions.Element (1).Arguments.Length), 3, Context & ": first launch argument count");
               Files_Suite.Support.Assert_Equal
                 (To_String (Actions.Element (1).Arguments.Element (2)), "/tmp/a.txt", Context & ": first target");
               Files_Suite.Support.Assert_Equal
                 (Natural (Actions.Element (2).Arguments.Length), 3, Context & ": second launch argument count");
               Files_Suite.Support.Assert_Equal
                 (To_String (Actions.Element (2).Arguments.Element (2)), "/tmp/b.txt", Context & ": second target");
            end;

            Actions := Files.Applications.Build_Open_Actions (Viewer, Targets);
            Assert
              (Natural (Actions.Length) = 1
               and then Natural (Actions.First_Element.Arguments.Length) = 3,
               "multi-file fields retain one launch containing every target");

            Action := Files.Applications.Build_Open_Action (Percent_App, Targets);
            Assert
              (To_String (Action.Executable) = "viewer%tool"
               and then Natural (Action.Arguments.Length) = 2,
               "a doubled percent is decoded in the executable token");
         end;
      end Check;
   begin
      With_Desktop_Application_Fixture (Check'Access);
   end Test_Desktop_Exec_Expansion;
