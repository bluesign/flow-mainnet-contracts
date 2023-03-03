import MessageCard from 0xf38fadaba79009cc

pub contract MessageCardRenderers {
    pub struct SvgPartsRenderer: MessageCard.IRenderer {
        pub let svgParts: [String]
        pub let replaceKeyAndParamKeys: {String: String}
        pub let extraData: {String: AnyStruct}

        pub fun render(params: {String: AnyStruct}): MessageCard.RenderResult {
            return MessageCard.RenderResult(
                dataType: "svg",
                data: self.generateSvg(params: params),
                extraData: self.extraData,
            )
        }

        pub fun generateSvg(params: {String: AnyStruct}): String {
            var svg = ""
            for svgPart in self.svgParts {
                let paramKey = self.replaceKeyAndParamKeys[svgPart]
                if paramKey != nil {
                    svg = svg.concat(params[paramKey!] != nil ? (params[paramKey!]! as! String) : "")
                } else {
                    svg = svg.concat(svgPart)
                }
            }
            return svg
        }

        init(
            svgParts: [String],
            replaceKeyAndParamKeys: {String: String},
            extraData: {String: AnyStruct},
        ) {
            self.svgParts = svgParts
            self.replaceKeyAndParamKeys = replaceKeyAndParamKeys
            self.extraData = extraData
        }
    }
}
