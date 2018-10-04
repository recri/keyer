# -*- mode: Tcl; tab-width: 8; -*-
#
# Copyright (C) 2018 by Roger E Critchlow Jr, Charlestown, MA, USA
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# 

# conversion of parts from https://github.com/bokeh/bokeh/palette.py

###########################################################################
# License regarding the Viridis, Magma, Plasma and Inferno colormaps:
#
# New matplotlib colormaps by Nathaniel J. Smith, Stefan van der Walt,
# and (in the case of viridis) Eric Firing.
#
# The Viridis, Magma, Plasma, and Inferno colormaps are released under the
# CC0 license / public domain dedication. We would appreciate credit if you
# use or redistribute these colormaps, but do not impose any legal
# restrictions.
#
# To the extent possible under law, the persons who associated CC0 with
# mpl-colormaps have waived all copyright and related or neighboring rights
# to mpl-colormaps.
#
# You should have received a copy of the CC0 legalcode along with this
# work.  If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
###########################################################################
# License regarding the brewer palettes:
#
# This product includes color specifications and designs developed by
# Cynthia Brewer (http://colorbrewer2.org/).  The Brewer colormaps are
# licensed under the Apache v2 license. You may obtain a copy of the
# License at http://www.apache.org/licenses/LICENSE-2.0
###########################################################################
# License regarding the cividis palette from https://github.com/pnnl/cmaputil
#
# Copyright (c) 2017, Battelle Memorial Institute
#
# 1.  Battelle Memorial Institute (hereinafter Battelle) hereby grants
# permission to any person or entity lawfully obtaining a copy of this software
# and associated documentation files (hereinafter "the Software") to
# redistribute and use the Software in source and binary forms, with or without
# modification. Such person or entity may use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and may permit
# others to do so, subject to the following conditions:
#
# + Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimers.
#
# + Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# + Other than as used herein, neither the name Battelle Memorial Institute or
# Battelle may be used in any form whatsoever without the express written
# consent of Battelle.
#
# 2.  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL BATTELLE OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###########################################################################
# License regarding the D3 color palettes (Category10, Category20,
# Category20b, and Category 20c):
#
# Copyright 2010-2015 Mike Bostock
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the author nor the names of contributors may be used to
#   endorse or promote products derived from this software without specific
#   prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###########################################################################
package provide palette 1.0

namespace eval ::palette {
    dict set palettes {*}{
	grey {
            #000000 #010101 #020202 #030303 #040404 #050505 #060606 #070707 #080808 #090909 #0a0a0a #0b0b0b
            #0c0c0c #0d0d0d #0e0e0e #0f0f0f #101010 #111111 #121212 #131313 #141414 #151515 #161616 #171717
            #181818 #191919 #1a1a1a #1b1b1b #1c1c1c #1d1d1d #1e1e1e #1f1f1f #202020 #212121 #222222 #232323
            #242424 #252525 #262626 #272727 #282828 #292929 #2a2a2a #2b2b2b #2c2c2c #2d2d2d #2e2e2e #2f2f2f
            #303030 #313131 #323232 #333333 #343434 #353535 #363636 #373737 #383838 #393939 #3a3a3a #3b3b3b
            #3c3c3c #3d3d3d #3e3e3e #3f3f3f #404040 #414141 #424242 #434343 #444444 #454545 #464646 #474747
            #484848 #494949 #4a4a4a #4b4b4b #4c4c4c #4d4d4d #4e4e4e #4f4f4f #505050 #515151 #525252 #535353
            #545454 #555555 #565656 #575757 #585858 #595959 #5a5a5a #5b5b5b #5c5c5c #5d5d5d #5e5e5e #5f5f5f
            #606060 #616161 #626262 #636363 #646464 #656565 #666666 #676767 #686868 #696969 #6a6a6a #6b6b6b
            #6c6c6c #6d6d6d #6e6e6e #6f6f6f #707070 #717171 #727272 #737373 #747474 #757575 #767676 #777777
            #787878 #797979 #7a7a7a #7b7b7b #7c7c7c #7d7d7d #7e7e7e #7f7f7f #808080 #818181 #828282 #838383
            #848484 #858585 #868686 #878787 #888888 #898989 #8a8a8a #8b8b8b #8c8c8c #8d8d8d #8e8e8e #8f8f8f
            #909090 #919191 #929292 #939393 #949494 #959595 #969696 #979797 #989898 #999999 #9a9a9a #9b9b9b
            #9c9c9c #9d9d9d #9e9e9e #9f9f9f #a0a0a0 #a1a1a1 #a2a2a2 #a3a3a3 #a4a4a4 #a5a5a5 #a6a6a6 #a7a7a7
            #a8a8a8 #a9a9a9 #aaaaaa #ababab #acacac #adadad #aeaeae #afafaf #b0b0b0 #b1b1b1 #b2b2b2 #b3b3b3
            #b4b4b4 #b5b5b5 #b6b6b6 #b7b7b7 #b8b8b8 #b9b9b9 #bababa #bbbbbb #bcbcbc #bdbdbd #bebebe #bfbfbf
            #c0c0c0 #c1c1c1 #c2c2c2 #c3c3c3 #c4c4c4 #c5c5c5 #c6c6c6 #c7c7c7 #c8c8c8 #c9c9c9 #cacaca #cbcbcb
            #cccccc #cdcdcd #cecece #cfcfcf #d0d0d0 #d1d1d1 #d2d2d2 #d3d3d3 #d4d4d4 #d5d5d5 #d6d6d6 #d7d7d7
            #d8d8d8 #d9d9d9 #dadada #dbdbdb #dcdcdc #dddddd #dedede #dfdfdf #e0e0e0 #e1e1e1 #e2e2e2 #e3e3e3
            #e4e4e4 #e5e5e5 #e6e6e6 #e7e7e7 #e8e8e8 #e9e9e9 #eaeaea #ebebeb #ececec #ededed #eeeeee #efefef
            #f0f0f0 #f1f1f1 #f2f2f2 #f3f3f3 #f4f4f4 #f5f5f5 #f6f6f6 #f7f7f7 #f8f8f8 #f9f9f9 #fafafa #fbfbfb
            #fcfcfc #fdfdfd #fefefe #ffffff
	}
	inferno {
            #000003 #000004 #000006 #010007 #010109 #01010B #02010E #020210 #030212 #040314 #040316 #050418
            #06041B #07051D #08061F #090621 #0A0723 #0B0726 #0D0828 #0E082A #0F092D #10092F #120A32 #130A34
            #140B36 #160B39 #170B3B #190B3E #1A0B40 #1C0C43 #1D0C45 #1F0C47 #200C4A #220B4C #240B4E #260B50
            #270B52 #290B54 #2B0A56 #2D0A58 #2E0A5A #300A5C #32095D #34095F #350960 #370961 #390962 #3B0964
            #3C0965 #3E0966 #400966 #410967 #430A68 #450A69 #460A69 #480B6A #4A0B6A #4B0C6B #4D0C6B #4F0D6C
            #500D6C #520E6C #530E6D #550F6D #570F6D #58106D #5A116D #5B116E #5D126E #5F126E #60136E #62146E
            #63146E #65156E #66156E #68166E #6A176E #6B176E #6D186E #6E186E #70196E #72196D #731A6D #751B6D
            #761B6D #781C6D #7A1C6D #7B1D6C #7D1D6C #7E1E6C #801F6B #811F6B #83206B #85206A #86216A #88216A
            #892269 #8B2269 #8D2369 #8E2468 #902468 #912567 #932567 #952666 #962666 #982765 #992864 #9B2864
            #9C2963 #9E2963 #A02A62 #A12B61 #A32B61 #A42C60 #A62C5F #A72D5F #A92E5E #AB2E5D #AC2F5C #AE305B
            #AF315B #B1315A #B23259 #B43358 #B53357 #B73456 #B83556 #BA3655 #BB3754 #BD3753 #BE3852 #BF3951
            #C13A50 #C23B4F #C43C4E #C53D4D #C73E4C #C83E4B #C93F4A #CB4049 #CC4148 #CD4247 #CF4446 #D04544
            #D14643 #D24742 #D44841 #D54940 #D64A3F #D74B3E #D94D3D #DA4E3B #DB4F3A #DC5039 #DD5238 #DE5337
            #DF5436 #E05634 #E25733 #E35832 #E45A31 #E55B30 #E65C2E #E65E2D #E75F2C #E8612B #E9622A #EA6428
            #EB6527 #EC6726 #ED6825 #ED6A23 #EE6C22 #EF6D21 #F06F1F #F0701E #F1721D #F2741C #F2751A #F37719
            #F37918 #F47A16 #F57C15 #F57E14 #F68012 #F68111 #F78310 #F7850E #F8870D #F8880C #F88A0B #F98C09
            #F98E08 #F99008 #FA9107 #FA9306 #FA9506 #FA9706 #FB9906 #FB9B06 #FB9D06 #FB9E07 #FBA007 #FBA208
            #FBA40A #FBA60B #FBA80D #FBAA0E #FBAC10 #FBAE12 #FBB014 #FBB116 #FBB318 #FBB51A #FBB71C #FBB91E
            #FABB21 #FABD23 #FABF25 #FAC128 #F9C32A #F9C52C #F9C72F #F8C931 #F8CB34 #F8CD37 #F7CF3A #F7D13C
            #F6D33F #F6D542 #F5D745 #F5D948 #F4DB4B #F4DC4F #F3DE52 #F3E056 #F3E259 #F2E45D #F2E660 #F1E864
            #F1E968 #F1EB6C #F1ED70 #F1EE74 #F1F079 #F1F27D #F2F381 #F2F485 #F3F689 #F4F78D #F5F891 #F6FA95
            #F7FB99 #F9FC9D #FAFDA0 #FCFEA4
	}

	magma {
            #000003 #000004 #000006 #010007 #010109 #01010B #02020D #02020F #030311 #040313 #040415 #050417
            #060519 #07051B #08061D #09071F #0A0722 #0B0824 #0C0926 #0D0A28 #0E0A2A #0F0B2C #100C2F #110C31
            #120D33 #140D35 #150E38 #160E3A #170F3C #180F3F #1A1041 #1B1044 #1C1046 #1E1049 #1F114B #20114D
            #221150 #231152 #251155 #261157 #281159 #2A115C #2B115E #2D1060 #2F1062 #301065 #321067 #341068
            #350F6A #370F6C #390F6E #3B0F6F #3C0F71 #3E0F72 #400F73 #420F74 #430F75 #450F76 #470F77 #481078
            #4A1079 #4B1079 #4D117A #4F117B #50127B #52127C #53137C #55137D #57147D #58157E #5A157E #5B167E
            #5D177E #5E177F #60187F #61187F #63197F #651A80 #661A80 #681B80 #691C80 #6B1C80 #6C1D80 #6E1E81
            #6F1E81 #711F81 #731F81 #742081 #762181 #772181 #792281 #7A2281 #7C2381 #7E2481 #7F2481 #812581
            #822581 #842681 #852681 #872781 #892881 #8A2881 #8C2980 #8D2980 #8F2A80 #912A80 #922B80 #942B80
            #952C80 #972C7F #992D7F #9A2D7F #9C2E7F #9E2E7E #9F2F7E #A12F7E #A3307E #A4307D #A6317D #A7317D
            #A9327C #AB337C #AC337B #AE347B #B0347B #B1357A #B3357A #B53679 #B63679 #B83778 #B93778 #BB3877
            #BD3977 #BE3976 #C03A75 #C23A75 #C33B74 #C53C74 #C63C73 #C83D72 #CA3E72 #CB3E71 #CD3F70 #CE4070
            #D0416F #D1426E #D3426D #D4436D #D6446C #D7456B #D9466A #DA4769 #DC4869 #DD4968 #DE4A67 #E04B66
            #E14C66 #E24D65 #E44E64 #E55063 #E65162 #E75262 #E85461 #EA5560 #EB5660 #EC585F #ED595F #EE5B5E
            #EE5D5D #EF5E5D #F0605D #F1615C #F2635C #F3655C #F3675B #F4685B #F56A5B #F56C5B #F66E5B #F6705B
            #F7715B #F7735C #F8755C #F8775C #F9795C #F97B5D #F97D5D #FA7F5E #FA805E #FA825F #FB8460 #FB8660
            #FB8861 #FB8A62 #FC8C63 #FC8E63 #FC9064 #FC9265 #FC9366 #FD9567 #FD9768 #FD9969 #FD9B6A #FD9D6B
            #FD9F6C #FDA16E #FDA26F #FDA470 #FEA671 #FEA873 #FEAA74 #FEAC75 #FEAE76 #FEAF78 #FEB179 #FEB37B
            #FEB57C #FEB77D #FEB97F #FEBB80 #FEBC82 #FEBE83 #FEC085 #FEC286 #FEC488 #FEC689 #FEC78B #FEC98D
            #FECB8E #FDCD90 #FDCF92 #FDD193 #FDD295 #FDD497 #FDD698 #FDD89A #FDDA9C #FDDC9D #FDDD9F #FDDFA1
            #FDE1A3 #FCE3A5 #FCE5A6 #FCE6A8 #FCE8AA #FCEAAC #FCECAE #FCEEB0 #FCF0B1 #FCF1B3 #FCF3B5 #FCF5B7
            #FBF7B9 #FBF9BB #FBFABD #FBFCBF
	}
	plasma {
            #0C0786 #100787 #130689 #15068A #18068B #1B068C #1D068D #1F058E #21058F #230590 #250591 #270592
            #290593 #2B0594 #2D0494 #2F0495 #310496 #330497 #340498 #360498 #380499 #3A049A #3B039A #3D039B
            #3F039C #40039C #42039D #44039E #45039E #47029F #49029F #4A02A0 #4C02A1 #4E02A1 #4F02A2 #5101A2
            #5201A3 #5401A3 #5601A3 #5701A4 #5901A4 #5A00A5 #5C00A5 #5E00A5 #5F00A6 #6100A6 #6200A6 #6400A7
            #6500A7 #6700A7 #6800A7 #6A00A7 #6C00A8 #6D00A8 #6F00A8 #7000A8 #7200A8 #7300A8 #7500A8 #7601A8
            #7801A8 #7901A8 #7B02A8 #7C02A7 #7E03A7 #7F03A7 #8104A7 #8204A7 #8405A6 #8506A6 #8607A6 #8807A5
            #8908A5 #8B09A4 #8C0AA4 #8E0CA4 #8F0DA3 #900EA3 #920FA2 #9310A1 #9511A1 #9612A0 #9713A0 #99149F
            #9A159E #9B179E #9D189D #9E199C #9F1A9B #A01B9B #A21C9A #A31D99 #A41E98 #A51F97 #A72197 #A82296
            #A92395 #AA2494 #AC2593 #AD2692 #AE2791 #AF2890 #B02A8F #B12B8F #B22C8E #B42D8D #B52E8C #B62F8B
            #B7308A #B83289 #B93388 #BA3487 #BB3586 #BC3685 #BD3784 #BE3883 #BF3982 #C03B81 #C13C80 #C23D80
            #C33E7F #C43F7E #C5407D #C6417C #C7427B #C8447A #C94579 #CA4678 #CB4777 #CC4876 #CD4975 #CE4A75
            #CF4B74 #D04D73 #D14E72 #D14F71 #D25070 #D3516F #D4526E #D5536D #D6556D #D7566C #D7576B #D8586A
            #D95969 #DA5A68 #DB5B67 #DC5D66 #DC5E66 #DD5F65 #DE6064 #DF6163 #DF6262 #E06461 #E16560 #E26660
            #E3675F #E3685E #E46A5D #E56B5C #E56C5B #E66D5A #E76E5A #E87059 #E87158 #E97257 #EA7356 #EA7455
            #EB7654 #EC7754 #EC7853 #ED7952 #ED7B51 #EE7C50 #EF7D4F #EF7E4E #F0804D #F0814D #F1824C #F2844B
            #F2854A #F38649 #F38748 #F48947 #F48A47 #F58B46 #F58D45 #F68E44 #F68F43 #F69142 #F79241 #F79341
            #F89540 #F8963F #F8983E #F9993D #F99A3C #FA9C3B #FA9D3A #FA9F3A #FAA039 #FBA238 #FBA337 #FBA436
            #FCA635 #FCA735 #FCA934 #FCAA33 #FCAC32 #FCAD31 #FDAF31 #FDB030 #FDB22F #FDB32E #FDB52D #FDB62D
            #FDB82C #FDB92B #FDBB2B #FDBC2A #FDBE29 #FDC029 #FDC128 #FDC328 #FDC427 #FDC626 #FCC726 #FCC926
            #FCCB25 #FCCC25 #FCCE25 #FBD024 #FBD124 #FBD324 #FAD524 #FAD624 #FAD824 #F9D924 #F9DB24 #F8DD24
            #F8DF24 #F7E024 #F7E225 #F6E425 #F6E525 #F5E726 #F5E926 #F4EA26 #F3EC26 #F3EE26 #F2F026 #F2F126
            #F1F326 #F0F525 #F0F623 #EFF821
	}
	viridis {
            #440154 #440255 #440357 #450558 #45065A #45085B #46095C #460B5E #460C5F #460E61 #470F62 #471163
            #471265 #471466 #471567 #471669 #47186A #48196B #481A6C #481C6E #481D6F #481E70 #482071 #482172
            #482273 #482374 #472575 #472676 #472777 #472878 #472A79 #472B7A #472C7B #462D7C #462F7C #46307D
            #46317E #45327F #45347F #453580 #453681 #443781 #443982 #433A83 #433B83 #433C84 #423D84 #423E85
            #424085 #414186 #414286 #404387 #404487 #3F4587 #3F4788 #3E4888 #3E4989 #3D4A89 #3D4B89 #3D4C89
            #3C4D8A #3C4E8A #3B508A #3B518A #3A528B #3A538B #39548B #39558B #38568B #38578C #37588C #37598C
            #365A8C #365B8C #355C8C #355D8C #345E8D #345F8D #33608D #33618D #32628D #32638D #31648D #31658D
            #31668D #30678D #30688D #2F698D #2F6A8D #2E6B8E #2E6C8E #2E6D8E #2D6E8E #2D6F8E #2C708E #2C718E
            #2C728E #2B738E #2B748E #2A758E #2A768E #2A778E #29788E #29798E #287A8E #287A8E #287B8E #277C8E
            #277D8E #277E8E #267F8E #26808E #26818E #25828E #25838D #24848D #24858D #24868D #23878D #23888D
            #23898D #22898D #228A8D #228B8D #218C8D #218D8C #218E8C #208F8C #20908C #20918C #1F928C #1F938B
            #1F948B #1F958B #1F968B #1E978A #1E988A #1E998A #1E998A #1E9A89 #1E9B89 #1E9C89 #1E9D88 #1E9E88
            #1E9F88 #1EA087 #1FA187 #1FA286 #1FA386 #20A485 #20A585 #21A685 #21A784 #22A784 #23A883 #23A982
            #24AA82 #25AB81 #26AC81 #27AD80 #28AE7F #29AF7F #2AB07E #2BB17D #2CB17D #2EB27C #2FB37B #30B47A
            #32B57A #33B679 #35B778 #36B877 #38B976 #39B976 #3BBA75 #3DBB74 #3EBC73 #40BD72 #42BE71 #44BE70
            #45BF6F #47C06E #49C16D #4BC26C #4DC26B #4FC369 #51C468 #53C567 #55C666 #57C665 #59C764 #5BC862
            #5EC961 #60C960 #62CA5F #64CB5D #67CC5C #69CC5B #6BCD59 #6DCE58 #70CE56 #72CF55 #74D054 #77D052
            #79D151 #7CD24F #7ED24E #81D34C #83D34B #86D449 #88D547 #8BD546 #8DD644 #90D643 #92D741 #95D73F
            #97D83E #9AD83C #9DD93A #9FD938 #A2DA37 #A5DA35 #A7DB33 #AADB32 #ADDC30 #AFDC2E #B2DD2C #B5DD2B
            #B7DD29 #BADE27 #BDDE26 #BFDF24 #C2DF22 #C5DF21 #C7E01F #CAE01E #CDE01D #CFE11C #D2E11B #D4E11A
            #D7E219 #DAE218 #DCE218 #DFE318 #E1E318 #E4E318 #E7E419 #E9E419 #ECE41A #EEE51B #F1E51C #F3E51E
            #F6E61F #F8E621 #FAE622 #FDE724
	}
	cividis {
            #00204C #00204E #002150 #002251 #002353 #002355 #002456 #002558 #00265A #00265B #00275D #00285F
            #002861 #002963 #002A64 #002A66 #002B68 #002C6A #002D6C #002D6D #002E6E #002E6F #002F6F #002F6F
            #00306F #00316F #00316F #00326E #00336E #00346E #00346E #01356E #06366E #0A376D #0E376D #12386D
            #15396D #17396D #1A3A6C #1C3B6C #1E3C6C #203C6C #223D6C #243E6C #263E6C #273F6C #29406B #2B416B
            #2C416B #2E426B #2F436B #31446B #32446B #33456B #35466B #36466B #37476B #38486B #3A496B #3B496B
            #3C4A6B #3D4B6B #3E4B6B #404C6B #414D6B #424E6B #434E6B #444F6B #45506B #46506B #47516B #48526B
            #49536B #4A536B #4B546B #4C556B #4D556B #4E566B #4F576C #50586C #51586C #52596C #535A6C #545A6C
            #555B6C #565C6C #575D6D #585D6D #595E6D #5A5F6D #5B5F6D #5C606D #5D616E #5E626E #5F626E #5F636E
            #60646E #61656F #62656F #63666F #64676F #65676F #666870 #676970 #686A70 #686A70 #696B71 #6A6C71
            #6B6D71 #6C6D72 #6D6E72 #6E6F72 #6F6F72 #6F7073 #707173 #717273 #727274 #737374 #747475 #757575
            #757575 #767676 #777776 #787876 #797877 #7A7977 #7B7A77 #7B7B78 #7C7B78 #7D7C78 #7E7D78 #7F7E78
            #807E78 #817F78 #828078 #838178 #848178 #858278 #868378 #878478 #888578 #898578 #8A8678 #8B8778
            #8C8878 #8D8878 #8E8978 #8F8A78 #908B78 #918C78 #928C78 #938D78 #948E78 #958F78 #968F77 #979077
            #989177 #999277 #9A9377 #9B9377 #9C9477 #9D9577 #9E9676 #9F9776 #A09876 #A19876 #A29976 #A39A75
            #A49B75 #A59C75 #A69C75 #A79D75 #A89E74 #A99F74 #AAA074 #ABA174 #ACA173 #ADA273 #AEA373 #AFA473
            #B0A572 #B1A672 #B2A672 #B4A771 #B5A871 #B6A971 #B7AA70 #B8AB70 #B9AB70 #BAAC6F #BBAD6F #BCAE6E
            #BDAF6E #BEB06E #BFB16D #C0B16D #C1B26C #C2B36C #C3B46C #C5B56B #C6B66B #C7B76A #C8B86A #C9B869
            #CAB969 #CBBA68 #CCBB68 #CDBC67 #CEBD67 #D0BE66 #D1BF66 #D2C065 #D3C065 #D4C164 #D5C263 #D6C363
            #D7C462 #D8C561 #D9C661 #DBC760 #DCC860 #DDC95F #DECA5E #DFCB5D #E0CB5D #E1CC5C #E3CD5B #E4CE5B
            #E5CF5A #E6D059 #E7D158 #E8D257 #E9D356 #EBD456 #ECD555 #EDD654 #EED753 #EFD852 #F0D951 #F1DA50
            #F3DB4F #F4DC4E #F5DD4D #F6DE4C #F7DF4B #F9E049 #FAE048 #FBE147 #FCE246 #FDE345 #FFE443 #FFE542
            #FFE642 #FFE743 #FFE844 #FFE945
	}
    }

    proc linear {name n} {
	# return a subset of n colors from the palette named $name
	set p [dict get $palette $name]
	set np [llength $p]
	if {$n > $np} {
	    error "requested $n colors from palette $name, but $name only has $np colors"
	}
	set sub {}
	for {set i 0} {$i < $n} {incr i} {
	    lappend sub [lindex $p [expr {int($i*$np/$n)}]]
	}
	return $sub
    }

    proc magma {n} { return [linear magma $n] }
    proc inferno {n} { return [linear inferno $n] }
    proc plasma {n} { return [linear plasma $n] }
    proc viridis {n} { return [linear viridis $n] }
    proc cividis {n} { return [linear cividis $n] }
    proc grey {n} { return [linear grey $n] }
    proc gray {n} { return [linear grey $n] }
}

