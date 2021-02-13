const hmacs = {}
const configuration = {
  useSrcset: true,
  backgroundColor: record => typeof record.backgroundColor == 'function' : record.backgroundColor(record) : record.backgroundColor,
  aspectRatio: record => typeof record.aspectRatio == 'function' : record.aspectRatio() : record.aspectRatio,
  hashKey: record => typeof record.hashKey == 'function' : record.hashKey() : record.hashKey
}

export function configure(configs) {
  Object.keys(configs).forEach(key => {
    configuration[key] = configs[key]
  })
}

export function setHmac(transformation, hmac){
  hmacs[transformation] = hmac;
}

export function setHost(host) {
  configuration.host = host;
}

export function bobRossUrl(hash, options) {
  options || (options = {});
    
  if (options['watermark'] === undefined) {
    options['watermark'] = {};
  }
  options['optimize'] = true;
    
  var query = [];
  var non_hmac_query = [];
  Object.keys(options).forEach(function (key) {
    const value = options[key];
    
    if (key == 'optimize') {
      query.push('O');
    } else if (key === 'progressive') {
      query.push('O');
    } else if (key === 'padding') {
      query.push('P' + value.toLowerCase());
    } else if (key === 'resize') {
      query.push('S' + value.toLowerCase());
    } else if (key === 'background') {
      query.push('B' + value.toLowerCase());
    } else if (key === 'expires') {
      query.push('E' + Math.floor(value.valueOf() / 1000).toString(16));
    } else if (key === 'watermark' && value) {
      query.push('W' + (value['id'] || 0).toString() + (value['position'] || 'se').toLowerCase() + (value['offset'] || ""))
    } else if (key === 'lossless') {
      query.push('L')
    } else if (key === 'transparent') {
      query.push('T')
    } else if (key === 'grayscale') {
      query.push('G')
    } else if (key === 'page') {
      non_hmac_query.push('R' + value);
    }
  });
    
  let hmac = hmacs[query.join('')];
    
  query = query.concat(non_hmac_query).join('');
    
  if (hmac) {
    return configuration.host + "/" + 'H' + hmac + encodeURIComponent(query) + "/" + hash;
  } else {
    return configuration.host + "/" + encodeURIComponent(query) + "/" + hash;
  }
}

export function bobRossSrcset(hash, options) {
  options || (options = {});
  var size_match = options.resize.match(/(\d+)x(\d+)(.*)/);
  var width = parseInt(size_match[1])
  var height = parseInt(size_match[2])
  var style = size_match[3]
  return [
    [bobRossUrl(hash, Object.assign({}, options, {resize: width * 2 + "x" + height * 2 + style} )), '2x'].join(" "),
    [bobRossUrl(hash, Object.assign({}, options, {resize: width * 3 + "x" + height * 3 + style} )), '3x'].join(" "),
  ].join(", ")
}


/*
  Options
  ----
  aspectRatio: 0.5, used to set image height/width
  backgroundColor: rgba(0,0,0,1)
*/
export function bobRossTag(object, options){
  options || (options = {});
  if(!object) {
    return null;
  }
  const hash = (typeof object === 'string') ? object : configuration.hashKey(object)

  var tag_options = {}
  Object.keys(options).forEach(key => {
    if(['item_prop', 'title', 'alt', 'class', 'size', 'id', 'data', 'srcset', 'style', 'sizes'].includes(key)){
      tag_options[key] = options[key]
    }
  })
  
  tag_options.alt || (tag_options.alt="");
  tag_options.style || (tag_options.style="");
  
  const backgroundColor = options.backgroundColor || configuration.backgroundColor(object)
  if(backgroundColor) {
    tag_options.style += "background-color: " + backgroundColor;
  }

  var size_match = options.resize.match(/(\d+)x(\d+)(.*)/)
  if (size_match){
    var width = parseInt(size_match[1])
    var height = parseInt(size_match[2])
    var style = size_match[3]

    if (["*", "#"].includes(style)) {
      tag_options.width = width;
      tag_options.height = height;
    } else {
      const aspectRatio = options.aspectRatio || configuration.aspectRatio(object)
      if (aspectRatio) {
        var output_width = height * aspectRatio;
        var output_height;
        if (output_width <= width) {
          output_height = height;
        } else {
          output_width = width;
          output_height = width / aspectRatio;
        }
      }

      tag_options.width || (tag_options.width = Math.ceil(output_width || width));
      tag_options.height || (tag_options.height = Math.ceil(output_height || height));
    }
    if(configuration.useSrcset){
      tag_options.srcset || (tag_options.srcset = bobRossSrcset(hash, options))
    }
  }
  
  const el = document.createElement('img')
  Object.keys(tag_options).forEach(key => {
    el.setAttribute(key, tag_options[key])
  })
  
  el.setAttribute('src', bobRossUrl(hash, options));
  return el
}