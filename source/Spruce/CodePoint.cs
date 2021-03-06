﻿using System;
using System.Collections.Generic;
using System.Text;

namespace Spruce {
    public class CodePoint {
        public readonly string FullText;
        public readonly int TextStart;
        public readonly int TextEnd;
        public readonly Tokens.Token Token;
        public readonly object Value;

        public CodePoint(string aFullText, int aTextStart, int aTextEnd, Tokens.Token aToken, object aValue) {
            FullText = aFullText;
            //
            TextStart = aTextStart;
            TextEnd = aTextEnd;
            //
            Token = aToken;
            Value = aValue;
        }

        // Useful during debugging. Otherwise not currently used but could be by user in Emitters.
        public override string ToString() {
            return Value.ToString();
        }
    }
}
