separate (Files.Commands)
   function Key_Text
     (Key : Guikit.Input.Key_Code)
      return String is
   begin
      case Key is
         when Guikit.Input.Key_0 =>
            return "0";
         when Guikit.Input.Key_1 =>
            return "1";
         when Guikit.Input.Key_2 =>
            return "2";
         when Guikit.Input.Key_3 =>
            return "3";
         when Guikit.Input.Key_4 =>
            return "4";
         when Guikit.Input.Key_A =>
            return "a";
         when Guikit.Input.Key_B =>
            return "b";
         when Guikit.Input.Key_C =>
            return "c";
         when Guikit.Input.Key_D =>
            return "d";
         when Guikit.Input.Key_F =>
            return "f";
         when Guikit.Input.Key_I =>
            return "i";
         when Guikit.Input.Key_L =>
            return "l";
         when Guikit.Input.Key_N =>
            return "n";
         when Guikit.Input.Key_P =>
            return "p";
         when Guikit.Input.Key_R =>
            return "r";
         when Guikit.Input.Key_S =>
            return "s";
         when Guikit.Input.Key_V =>
            return "v";
         when Guikit.Input.Key_X =>
            return "x";
         when Guikit.Input.Key_Z =>
            return "z";
         when Guikit.Input.Key_Comma =>
            return ",";
         when Guikit.Input.Key_Equal =>
            return "equal";
         when Guikit.Input.Key_Minus =>
            return "minus";
         when Guikit.Input.Key_Backspace =>
            return "backspace";
         when Guikit.Input.Key_Delete =>
            return "delete";
         when Guikit.Input.Key_F2 =>
            return "f2";
         when Guikit.Input.Key_F5 =>
            return "f5";
         when Guikit.Input.Key_Escape =>
            return "escape";
         when Guikit.Input.Key_Return =>
            return "return";
         when Guikit.Input.Key_Left =>
            return "left";
         when Guikit.Input.Key_Right =>
            return "right";
         when Guikit.Input.Key_Up =>
            return "up";
         when Guikit.Input.Key_Down =>
            return "down";
         when Guikit.Input.Key_Home =>
            return "home";
         when Guikit.Input.Key_End =>
            return "end";
         when Guikit.Input.Key_Page_Up =>
            return "pageup";
         when Guikit.Input.Key_Page_Down =>
            return "pagedown";
         when Guikit.Input.Key_Space =>
            return "space";
         when Guikit.Input.Key_5 => return "5";
         when Guikit.Input.Key_6 => return "6";
         when Guikit.Input.Key_7 => return "7";
         when Guikit.Input.Key_8 => return "8";
         when Guikit.Input.Key_9 => return "9";
         when Guikit.Input.Key_E => return "e";
         when Guikit.Input.Key_G => return "g";
         when Guikit.Input.Key_H => return "h";
         when Guikit.Input.Key_J => return "j";
         when Guikit.Input.Key_K => return "k";
         when Guikit.Input.Key_M => return "m";
         when Guikit.Input.Key_O => return "o";
         when Guikit.Input.Key_Q => return "q";
         when Guikit.Input.Key_T => return "t";
         when Guikit.Input.Key_U => return "u";
         when Guikit.Input.Key_W => return "w";
         when Guikit.Input.Key_Y => return "y";
         when Guikit.Input.Key_F1 => return "f1";
         when Guikit.Input.Key_F3 => return "f3";
         when Guikit.Input.Key_F4 => return "f4";
         when Guikit.Input.Key_F6 => return "f6";
         when Guikit.Input.Key_F7 => return "f7";
         when Guikit.Input.Key_F8 => return "f8";
         when Guikit.Input.Key_F9 => return "f9";
         when Guikit.Input.Key_F10 => return "f10";
         when Guikit.Input.Key_F11 => return "f11";
         when Guikit.Input.Key_F12 => return "f12";
         when Guikit.Input.Key_Tab => return "tab";
         when Guikit.Input.Key_Insert => return "insert";
         when Guikit.Input.Key_Unknown =>
            return "";
      end case;
   end Key_Text;
