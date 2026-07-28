separate (Files.Application.Windows)
   function To_Glfw_Key
     (Key : Tracked_Key)
      return Glfw.Input.Keys.Key is
   begin
      case Key is
         when Tracked_Key_1 =>
            return Glfw.Input.Keys.Key_1;
         when Tracked_Key_2 =>
            return Glfw.Input.Keys.Key_2;
         when Tracked_Key_3 =>
            return Glfw.Input.Keys.Key_3;
         when Tracked_Key_4 =>
            return Glfw.Input.Keys.Key_4;
         when Tracked_A =>
            return Glfw.Input.Keys.A;
         when Tracked_B =>
            return Glfw.Input.Keys.B;
         when Tracked_C =>
            return Glfw.Input.Keys.C;
         when Tracked_D =>
            return Glfw.Input.Keys.D;
         when Tracked_F =>
            return Glfw.Input.Keys.F;
         when Tracked_I =>
            return Glfw.Input.Keys.I;
         when Tracked_L =>
            return Glfw.Input.Keys.L;
         when Tracked_N =>
            return Glfw.Input.Keys.N;
         when Tracked_P =>
            return Glfw.Input.Keys.P;
         when Tracked_R =>
            return Glfw.Input.Keys.R;
         when Tracked_S =>
            return Glfw.Input.Keys.S;
         when Tracked_V =>
            return Glfw.Input.Keys.V;
         when Tracked_X =>
            return Glfw.Input.Keys.X;
         when Tracked_Z =>
            return Glfw.Input.Keys.Z;
         when Tracked_Comma =>
            return Glfw.Input.Keys.Comma;
         when Tracked_Backspace =>
            return Glfw.Input.Keys.Backspace;
         when Tracked_Delete =>
            return Glfw.Input.Keys.Delete;
         when Tracked_F2 =>
            return Glfw.Input.Keys.F2;
         when Tracked_F5 =>
            return Glfw.Input.Keys.F5;
         when Tracked_Escape =>
            return Glfw.Input.Keys.Escape;
         when Tracked_Enter =>
            return Glfw.Input.Keys.Enter;
         when Tracked_Numpad_Enter =>
            return Glfw.Input.Keys.Numpad_Enter;
         when Tracked_Left =>
            return Glfw.Input.Keys.Left;
         when Tracked_Right =>
            return Glfw.Input.Keys.Right;
         when Tracked_Up =>
            return Glfw.Input.Keys.Up;
         when Tracked_Down =>
            return Glfw.Input.Keys.Down;
         when Tracked_Home =>
            return Glfw.Input.Keys.Home;
         when Tracked_End =>
            return Glfw.Input.Keys.Key_End;
         when Tracked_Page_Up =>
            return Glfw.Input.Keys.Page_Up;
         when Tracked_Page_Down =>
            return Glfw.Input.Keys.Page_Down;
         when Tracked_Equal =>
            return Glfw.Input.Keys.Equal;
         when Tracked_Minus =>
            return Glfw.Input.Keys.Minus;
         when Tracked_Right_Bracket =>
            return Glfw.Input.Keys.Right_Bracket;
         when Tracked_Slash =>
            return Glfw.Input.Keys.Slash;
         when Tracked_Numpad_Add =>
            return Glfw.Input.Keys.Numpad_Add;
         when Tracked_Numpad_Subtract =>
            return Glfw.Input.Keys.Numpad_Substract;
         when Tracked_Zero =>
            return Glfw.Input.Keys.Key_0;
         when Tracked_Space =>
            return Glfw.Input.Keys.Space;
         when Tracked_Key_5 =>
            return Glfw.Input.Keys.Key_5;
         when Tracked_Key_6 =>
            return Glfw.Input.Keys.Key_6;
         when Tracked_Key_7 =>
            return Glfw.Input.Keys.Key_7;
         when Tracked_Key_8 =>
            return Glfw.Input.Keys.Key_8;
         when Tracked_Key_9 =>
            return Glfw.Input.Keys.Key_9;
         when Tracked_E =>
            return Glfw.Input.Keys.E;
         when Tracked_G =>
            return Glfw.Input.Keys.G;
         when Tracked_H =>
            return Glfw.Input.Keys.H;
         when Tracked_J =>
            return Glfw.Input.Keys.J;
         when Tracked_K =>
            return Glfw.Input.Keys.K;
         when Tracked_M =>
            return Glfw.Input.Keys.M;
         when Tracked_O =>
            return Glfw.Input.Keys.O;
         when Tracked_Q =>
            return Glfw.Input.Keys.Q;
         when Tracked_T =>
            return Glfw.Input.Keys.T;
         when Tracked_U =>
            return Glfw.Input.Keys.U;
         when Tracked_W =>
            return Glfw.Input.Keys.W;
         when Tracked_Y =>
            return Glfw.Input.Keys.Y;
         when Tracked_F1 =>
            return Glfw.Input.Keys.F1;
         when Tracked_F3 =>
            return Glfw.Input.Keys.F3;
         when Tracked_F4 =>
            return Glfw.Input.Keys.F4;
         when Tracked_F6 =>
            return Glfw.Input.Keys.F6;
         when Tracked_F7 =>
            return Glfw.Input.Keys.F7;
         when Tracked_F8 =>
            return Glfw.Input.Keys.F8;
         when Tracked_F9 =>
            return Glfw.Input.Keys.F9;
         when Tracked_F10 =>
            return Glfw.Input.Keys.F10;
         when Tracked_F11 =>
            return Glfw.Input.Keys.F11;
         when Tracked_F12 =>
            return Glfw.Input.Keys.F12;
         when Tracked_Tab =>
            return Glfw.Input.Keys.Tab;
         when Tracked_Insert =>
            return Glfw.Input.Keys.Insert;
      end case;
   end To_Glfw_Key;
