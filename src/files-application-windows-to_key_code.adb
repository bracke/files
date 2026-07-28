separate (Files.Application.Windows)
   function To_Key_Code
     (Key : Tracked_Key)
      return Guikit.Input.Key_Code is
   begin
      case Key is
         when Tracked_Key_1 =>
            return Guikit.Input.Key_1;
         when Tracked_Key_2 =>
            return Guikit.Input.Key_2;
         when Tracked_Key_3 =>
            return Guikit.Input.Key_3;
         when Tracked_Key_4 =>
            return Guikit.Input.Key_4;
         when Tracked_A =>
            return Guikit.Input.Key_A;
         when Tracked_B =>
            return Guikit.Input.Key_B;
         when Tracked_C =>
            return Guikit.Input.Key_C;
         when Tracked_D =>
            return Guikit.Input.Key_D;
         when Tracked_F =>
            return Guikit.Input.Key_F;
         when Tracked_I =>
            return Guikit.Input.Key_I;
         when Tracked_L =>
            return Guikit.Input.Key_L;
         when Tracked_N =>
            return Guikit.Input.Key_N;
         when Tracked_P =>
            return Guikit.Input.Key_P;
         when Tracked_R =>
            return Guikit.Input.Key_R;
         when Tracked_S =>
            return Guikit.Input.Key_S;
         when Tracked_V =>
            return Guikit.Input.Key_V;
         when Tracked_X =>
            return Guikit.Input.Key_X;
         when Tracked_Z =>
            return Guikit.Input.Key_Z;
         when Tracked_Comma =>
            return Guikit.Input.Key_Comma;
         when Tracked_Backspace =>
            return Guikit.Input.Key_Backspace;
         when Tracked_Delete =>
            return Guikit.Input.Key_Delete;
         when Tracked_F2 =>
            return Guikit.Input.Key_F2;
         when Tracked_F5 =>
            return Guikit.Input.Key_F5;
         when Tracked_Escape =>
            return Guikit.Input.Key_Escape;
         when Tracked_Enter | Tracked_Numpad_Enter =>
            return Guikit.Input.Key_Return;
         when Tracked_Left =>
            return Guikit.Input.Key_Left;
         when Tracked_Right =>
            return Guikit.Input.Key_Right;
         when Tracked_Up =>
            return Guikit.Input.Key_Up;
         when Tracked_Down =>
            return Guikit.Input.Key_Down;
         when Tracked_Home =>
            return Guikit.Input.Key_Home;
         when Tracked_End =>
            return Guikit.Input.Key_End;
         when Tracked_Page_Up =>
            return Guikit.Input.Key_Page_Up;
         when Tracked_Page_Down =>
            return Guikit.Input.Key_Page_Down;
         --  The '+' family (physical '=', ']' and numpad '+') maps to Key_Equal
         --  and the '-' family (physical '-', '/' and numpad '-') to Key_Minus
         --  so the shared keyboard-zoom seam handles Ctrl+plus / Ctrl+minus.
         --  The alternate ']' and '/' positions cover layouts (e.g. German)
         --  where '+' and '-' sit on those physical keys.
         when Tracked_Equal | Tracked_Right_Bracket | Tracked_Numpad_Add =>
            return Guikit.Input.Key_Equal;
         when Tracked_Minus | Tracked_Slash | Tracked_Numpad_Subtract =>
            return Guikit.Input.Key_Minus;
         when Tracked_Zero =>
            return Guikit.Input.Key_0;
         when Tracked_Space =>
            return Guikit.Input.Key_Space;
         when Tracked_Key_5 =>
            return Guikit.Input.Key_5;
         when Tracked_Key_6 =>
            return Guikit.Input.Key_6;
         when Tracked_Key_7 =>
            return Guikit.Input.Key_7;
         when Tracked_Key_8 =>
            return Guikit.Input.Key_8;
         when Tracked_Key_9 =>
            return Guikit.Input.Key_9;
         when Tracked_E =>
            return Guikit.Input.Key_E;
         when Tracked_G =>
            return Guikit.Input.Key_G;
         when Tracked_H =>
            return Guikit.Input.Key_H;
         when Tracked_J =>
            return Guikit.Input.Key_J;
         when Tracked_K =>
            return Guikit.Input.Key_K;
         when Tracked_M =>
            return Guikit.Input.Key_M;
         when Tracked_O =>
            return Guikit.Input.Key_O;
         when Tracked_Q =>
            return Guikit.Input.Key_Q;
         when Tracked_T =>
            return Guikit.Input.Key_T;
         when Tracked_U =>
            return Guikit.Input.Key_U;
         when Tracked_W =>
            return Guikit.Input.Key_W;
         when Tracked_Y =>
            return Guikit.Input.Key_Y;
         when Tracked_F1 =>
            return Guikit.Input.Key_F1;
         when Tracked_F3 =>
            return Guikit.Input.Key_F3;
         when Tracked_F4 =>
            return Guikit.Input.Key_F4;
         when Tracked_F6 =>
            return Guikit.Input.Key_F6;
         when Tracked_F7 =>
            return Guikit.Input.Key_F7;
         when Tracked_F8 =>
            return Guikit.Input.Key_F8;
         when Tracked_F9 =>
            return Guikit.Input.Key_F9;
         when Tracked_F10 =>
            return Guikit.Input.Key_F10;
         when Tracked_F11 =>
            return Guikit.Input.Key_F11;
         when Tracked_F12 =>
            return Guikit.Input.Key_F12;
         when Tracked_Tab =>
            return Guikit.Input.Key_Tab;
         when Tracked_Insert =>
            return Guikit.Input.Key_Insert;
      end case;
   end To_Key_Code;
