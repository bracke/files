separate (Files_Suite.Startup)
   procedure Test_Desktop_Input_Mapping (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (Character'Pos ('A'))),
         "A",
         "desktop text input preserves printable ASCII");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00E9#)),
         Byte (16#C3#) & Byte (16#A9#),
         "desktop text input encodes two-byte UTF-8");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#20AC#)),
         Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#),
         "desktop text input encodes three-byte UTF-8");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#1F4C1#)),
         Byte (16#F0#) & Byte (16#9F#) & Byte (16#93#) & Byte (16#81#),
         "desktop text input encodes four-byte UTF-8");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (9)),
         "",
         "desktop text input ignores control characters");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#D800#)),
         "",
         "desktop text input ignores surrogate code points");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (100), Glfw.Size (200)),
         100,
         "runtime coordinate scaling maps proportional positions");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Scale_Coordinate (-1.0, Glfw.Size (100), Glfw.Size (200)),
         0,
         "runtime coordinate scaling clamps negative cursor positions");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Scale_Coordinate (150.0, Glfw.Size (100), Glfw.Size (200)),
         200,
         "runtime coordinate scaling clamps beyond framebuffer size");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (0), Glfw.Size (200)),
         0,
         "runtime coordinate scaling rejects zero source dimensions");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Scale_Coordinate (50.0, Glfw.Size (100), Glfw.Size (0)),
         0,
         "runtime coordinate scaling rejects zero target dimensions");
      Assert
        (Files.Application.Windows.Scrollbar_Drag_Offset
           (Thumb_Top => 0, Track_Length => 100, Thumb_Length => 20, Maximum => 17) = 0,
         "scrollbar dragging maps the top of the track to zero");
      Assert
        (Files.Application.Windows.Scrollbar_Drag_Offset
           (Thumb_Top => 40, Track_Length => 100, Thumb_Length => 20, Maximum => 17) = 8,
         "scrollbar dragging maps intermediate thumb travel proportionally");
      Assert
        (Files.Application.Windows.Scrollbar_Drag_Offset
           (Thumb_Top => 80, Track_Length => 100, Thumb_Length => 20, Maximum => 17) = 17,
         "scrollbar dragging reaches a partial final page exactly");
      Assert
        (Files.Application.Windows.Scrollbar_Drag_Offset
           (Thumb_Top => 200, Track_Length => 100, Thumb_Length => 20, Maximum => 17) = 17,
         "scrollbar dragging clamps positions beyond the track");
      Assert
        (Files.Application.Windows.Scrollbar_Drag_Offset
           (Thumb_Top => 1, Track_Length => 20, Thumb_Length => 20, Maximum => 17) = 0,
         "scrollbar dragging is inert when the thumb has no travel");
      Assert
        (Files.Application.Windows.Cursor_Is_Inside_Window
           (0.0, 0.0, Glfw.Size (100), Glfw.Size (80)),
         "the first window pixel is inside the raw cursor bounds");
      Assert
        (Files.Application.Windows.Cursor_Is_Inside_Window
           (99.5, 79.5, Glfw.Size (100), Glfw.Size (80)),
         "fractional coordinates before the far edges remain inside");
      Assert
        (not Files.Application.Windows.Cursor_Is_Inside_Window
           (-0.01, 20.0, Glfw.Size (100), Glfw.Size (80)),
         "a raw cursor left of the window is outside rather than pixel zero");
      Assert
        (not Files.Application.Windows.Cursor_Is_Inside_Window
           (20.0, -0.01, Glfw.Size (100), Glfw.Size (80)),
         "a raw cursor above the window is outside rather than pixel zero");
      Assert
        (not Files.Application.Windows.Cursor_Is_Inside_Window
           (100.0, 20.0, Glfw.Size (100), Glfw.Size (80)),
         "the right window extent is outside");
      Assert
        (not Files.Application.Windows.Cursor_Is_Inside_Window
           (20.0, 80.0, Glfw.Size (100), Glfw.Size (80)),
         "the bottom window extent is outside");
   end Test_Desktop_Input_Mapping;
