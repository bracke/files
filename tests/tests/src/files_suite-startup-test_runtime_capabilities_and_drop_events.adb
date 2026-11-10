with Files.Drop_Events.Testing;
separate (Files_Suite.Startup)
   procedure Test_Runtime_Capabilities_And_Drop_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir  : constant String := Join (Root, "report-dir");
      Caps : constant Files.Application.Windows.Desktop_Capabilities :=
        Files.Application.Windows.Runtime_Capabilities;
   begin
      Files_Suite.Support.Assert_Equal
        (Caps.Live_Window_Smoke_Ready,
         (Caps.Display_Available and then Caps.Vulkan_Available),
         "runtime capabilities gate live window smoke on display and Vulkan");
      declare
         Source        : Files.Drop_Events.Drop_Event_Source;
         Paths         : Files.Types.String_Vectors.Vector;
         Drained       : Files.Types.String_Vectors.Vector;
         Mode          : Files.File_System.Drop_Import_Mode;
      begin
         Paths.Append (To_Unbounded_String (""));
         Paths.Append (To_Unbounded_String ("  " & Dir & "  "));
         Files.Drop_Events.Queue (Source, Paths, Files.File_System.Drop_Move);
         Assert (Files.Drop_Events.Has_Pending (Source), "drop event source queues non-empty paths");
         Files_Suite.Support.Assert_Equal
           (Files.Drop_Events.Testing.Pending_Count (Source),
            1,
            "drop event source filters empty paths");
         Files.Drop_Events.Take (Source, Drained, Mode);
         Assert (Mode = Files.File_System.Drop_Move, "drop event source preserves queued import mode");
         Files_Suite.Support.Assert_Equal (Natural (Drained.Length), 1, "drop event source drains one filtered path");
         Files_Suite.Support.Assert_Equal
           (To_String (Drained.Element (1)),
            "  " & Dir & "  ",
            "drop event source preserves native path whitespace");
         Assert (not Files.Drop_Events.Has_Pending (Source), "drop event source clears after drain");
         declare
            Too_Many : Files.Types.String_Vectors.Vector;
         begin
            for Index in 1 .. Files.Drop_Events.Max_Paths + 1 loop
               Too_Many.Append (To_Unbounded_String (Dir));
            end loop;
            Files.Drop_Events.Queue (Source, Too_Many);
            Assert (not Files.Drop_Events.Has_Pending (Source),
                    "a drop over the path limit is refused whole, not imported in part");
            Assert (Files.Drop_Events.Take_Overflow (Source), "the refused drop is reported once");
            Assert (not Files.Drop_Events.Take_Overflow (Source), "the refusal report clears after it is taken");
         end;
      end;
   end Test_Runtime_Capabilities_And_Drop_Events;
