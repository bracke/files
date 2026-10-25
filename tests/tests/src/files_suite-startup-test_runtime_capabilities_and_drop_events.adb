separate (Files_Suite.Startup)
   procedure Test_Runtime_Capabilities_And_Drop_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir  : constant String := Join (Root, "report-dir");
      Caps : constant Files.Application.Windows.Desktop_Capabilities :=
        Files.Application.Windows.Runtime_Capabilities;
   begin
      Assert (Caps.Headless_Rendering, "runtime capabilities advertise headless rendering");
      Files_Suite.Support.Assert_Equal
        (Caps.Live_Window_Smoke_Ready,
         (Caps.Display_Available and then Caps.Vulkan_Available),
         "runtime capabilities gate live window smoke on display and Vulkan");
      Assert (Caps.Event_Translation_Model, "runtime capabilities expose event translation model");
      Assert (Caps.Focus_Runtime_Model, "runtime capabilities expose focus model");
      Assert (Caps.Resize_Runtime_Model, "runtime capabilities expose resize model");
      Assert (Caps.Scroll_Runtime_Model, "runtime capabilities expose scroll model");
      Assert (Caps.Native_Drop_Callbacks, "runtime capabilities expose native drop callbacks");
      Assert
        (Caps.Native_Drop_Automation,
         "runtime capabilities expose drop event-source automation");
      declare
         Drop_Profile : constant Files.Application.Windows.Native_Drag_Automation_Profile :=
           Files.Application.Windows.Native_Drag_Automation_Profile_Of_Current_Runtime;
         Event_Profile : constant Files.Drop_Events.Drop_Event_Source_Profile := Files.Drop_Events.Profile;
         Source        : Files.Drop_Events.Drop_Event_Source;
         Paths         : Files.Types.String_Vectors.Vector;
         Drained       : Files.Types.String_Vectors.Vector;
         Mode          : Files.File_System.Drop_Import_Mode;
      begin
         Assert (Drop_Profile.Native_Drop_Callbacks, "drag automation profile keeps native drop callbacks separate");
         Assert
           (not Drop_Profile.Portable_GLFW_Automation,
            "drag automation profile rejects portable GLFW event synthesis");
         Assert (Drop_Profile.Event_Source_Backend, "drag automation profile exposes an Ada event-source backend");
         Assert (Drop_Profile.Queued_Drop_Imports, "drag automation profile supports queued drop imports");
         Assert
           (not Drop_Profile.Requires_OS_Event_Source,
            "drag automation profile no longer blocks on OS event-source backends");
         Files_Suite.Support.Assert_Equal
           (Drop_Profile.Max_Paths,
            Event_Profile.Max_Paths,
            "drag automation profile uses the drop event backend path limit");
         Files_Suite.Support.Assert_Equal
           (To_String (Drop_Profile.Binding_Unit),
            "Files.Drop_Events",
            "drag automation profile records owning backend unit");
         Assert (Event_Profile.Event_Source_Backend, "drop event backend profile exposes event-source support");
         Paths.Append (To_Unbounded_String (""));
         Paths.Append (To_Unbounded_String ("  " & Dir & "  "));
         Files.Drop_Events.Queue (Source, Paths, Files.File_System.Drop_Move);
         Assert (Files.Drop_Events.Has_Pending (Source), "drop event source queues non-empty paths");
         Files_Suite.Support.Assert_Equal
           (Files.Drop_Events.Pending_Count (Source),
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
            for Index in 1 .. Event_Profile.Max_Paths + 1 loop
               Too_Many.Append (To_Unbounded_String (Dir));
            end loop;
            Files.Drop_Events.Queue (Source, Too_Many);
            Assert (not Files.Drop_Events.Has_Pending (Source),
                    "a drop over the path limit is refused whole, not imported in part");
            Assert (Files.Drop_Events.Take_Overflow (Source), "the refused drop is reported once");
            Assert (not Files.Drop_Events.Take_Overflow (Source), "the refusal report clears after it is taken");
         end;
      end;
      Assert (Caps.Directory_Watch_Polling, "runtime capabilities expose directory watch polling");
      Assert (Caps.Native_File_Watching, "runtime capabilities expose native file watching");
   end Test_Runtime_Capabilities_And_Drop_Events;
