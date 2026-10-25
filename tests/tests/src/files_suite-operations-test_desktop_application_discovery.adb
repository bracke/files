separate (Files_Suite.Operations)
   procedure Test_Desktop_Application_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Find
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String)
         return Files.Applications.Application renames Find_Application;

      function Count_Name
        (Apps : Files.Applications.Application_Vectors.Vector;
         Name : String) return Natural
      is
         Result : Natural := 0;
      begin
         for App of Apps loop
            if To_String (App.Name) = Name then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count_Name;

      procedure Check is
         Apps : constant Files.Applications.Application_Vectors.Vector :=
           Files.Applications.Available_Applications;
         Editor : constant Files.Applications.Application := Find (Apps, "Text Editor");
         Viewer : constant Files.Applications.Application := Find (Apps, "Image Viewer");
      begin
         Files_Suite.Support.Assert_Equal
           (Natural (Apps.Length),
            13,
            "valid desktop IDs are returned without collapsing shared display names");
         Files_Suite.Support.Assert_Equal
           (To_String (Apps.First_Element.Name),
            "Dansk Program",
            "applications use and sort by the best localized decoded name");
         Files_Suite.Support.Assert_Equal
           (Count_Name (Apps, "Shared Name"),
            2,
            "distinct desktop IDs may expose the same application name");
         Assert
           (To_String (Find (Apps, "Should Stay Masked").Exec) = ""
            and then To_String (Find (Apps, "System Editor").Exec) = "",
            "higher-priority desktop IDs mask lower-priority system entries");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Try Missing").Exec),
            "",
            "an unavailable TryExec keeps an application out of the picker");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Oversized Entry").Exec),
            "",
            "oversized desktop entries are rejected before line allocation");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Linked Application").Exec),
            "",
            "application discovery refuses linked desktop entries");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "Excessive Exec").Exec),
            "",
            "desktop entries with excessive Exec vectors are rejected");
         Files_Suite.Support.Assert_Equal
           (To_String (Find (Apps, "ZZ CRLF Application").Exec),
            "viewer %F",
            "desktop entries with CRLF line endings are accepted");
         Assert
           (To_String (Find (Apps, "Invalid Boolean").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Key").Exec) = ""
            and then To_String (Find (Apps, "Duplicate Group").Exec) = "",
            "invalid booleans, duplicate keys, and duplicate groups are rejected");
         Assert
           (To_String (Find (Apps, "Duplicate Auxiliary Group").Exec) = ""
            and then To_String (Find (Apps, "Malformed Line").Exec) = ""
            and then To_String (Find (Apps, "Malformed Group").Exec) = "",
            "malformed syntax and duplicate auxiliary groups are rejected");
         Assert
           (To_String (Find (Apps, "Localized Name Only").Exec) = ""
            and then To_String (Find (Apps, "Localized Icon Only").Exec) = "",
            "localized values require their unlocalized base keys");
         Assert
           (To_String (Find (Apps, "V Current Desktop").Exec) /= ""
            and then To_String (Find (Apps, "Only Other Desktop").Exec) = ""
            and then To_String (Find (Apps, "Not Current Desktop").Exec) = ""
            and then To_String
              (Find (Apps, "W Other Desktop Exclusion").Exec) /= "",
            "desktop visibility keys are applied to every current desktop name");
         Assert
           (To_String (Find (Apps, "X Both Visibility Lists").Exec) /= ""
            and then To_String
              (Find (Apps, "Excluded By Later Desktop").Exec) = ""
            and then To_String (Find (Apps, "Y Escaped Desktop Name").Exec) /= ""
            and then To_String (Find (Apps, "Invalid List Escape").Exec) = ""
            and then To_String
              (Find (Apps, "Overlapping Visibility Lists").Exec) = "",
            "visibility lists decode escapes, honor later exclusions, and permit only disjoint coexistence");
         Files_Suite.Support.Assert_Equal
           (To_String (Editor.Exec),
            "editor %F",
            "the desktop Exec template is retained for positional expansion");
         Files_Suite.Support.Assert_Equal
           (To_String (Viewer.Exec),
            "viewer --open %U",
            "base arguments and their target field position are retained");
      end Check;
   begin
      With_Desktop_Application_Fixture (Check'Access);
   end Test_Desktop_Application_Discovery;
