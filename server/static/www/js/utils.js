var utils = {
    FormToJson: function (formData) {
        var objData = {};
        formData.forEach((value, key) => objData[key] = value);
        return JSON.stringify(objData);
    },

    StringFormat: function (str, data) {
        if (!str || data == undefined) {
            return str;
        }

        if (typeof data === "object") {
            for (var key in data) {
                if (data.hasOwnProperty(key)) {
                    str = str.replace(new RegExp("\{" + key + "\}", "g"), data[key]);
                }
            }
        } else {
            var args = arguments,
                reg = new RegExp("\{([0-" + (args.length - 1) + "])\}", "g");
            return str.replace(reg, function (match, index) {
                return args[index - (-1)];
            });
        }
        return str;
    },

    SaveToken: function(token) {
        axios.defaults.headers.common['Authorization'] = 'Bearer ' + token;
        document.cookie = 'token=' + token + ';path=/';
    }
    ,
    ClearToken: function() {
        axios.defaults.headers.common['Authorization'] = "";
        document.cookie = 'token=' + "" + ';path=/';
    }
    ,
    HTMLEncode: function(html) {
        var temp = document.createElement("div");
        (temp.textContent != null) ? (temp.textContent = html) : (temp.innerText = html);
        var output = temp.innerHTML;
        temp = null;
        return output;
    }
}

